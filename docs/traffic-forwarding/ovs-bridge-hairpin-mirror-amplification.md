# 同桥回灌导致镜像自采集放大

> **位置**：workspace 仓 `docs/traffic-forwarding/`。  
> 状态（2026-09）：现场已确认「underlay 出口 VXLAN 回灌进业务口 ingress」；  
> 产品侧已在 `handle_ingress` 增加与 egress 相同的自有 VXLAN UDP dport 跳过。  
> 桥上是否一定是 VLAN 1002 未知单播 flood，未作为定论强求；同桥回灌本身已足够解释现象。

---

## 1. 现象

- 采集/转发流量出现**周期性满速平台**，高度与 `veth_a` 上 **TBF `rate` 几乎一致**。
- 放开 TBF 后「采集量」变大（盖子抬高）。
- `collected_bytes` 与经 TBF 送出的量大致同级（不是成倍爆炸，而是被整形卡住的稳态环/跟拍）。
- 方向抓包：

```text
underlay (如 mgm)  -Q out : 能看见自有 VXLAN
业务口   (如 biz)  -Q in  : 也能看见同一批自有 VXLAN
业务口             -Q out : 没有
```

说明：**不是业务口自己发出去的，而是别人（同桥转发）又送进业务口入向。**

---

## 2. 拓扑前提

业务口与 underlay 口挂在**同一 OVS bridge**（现场例：`br-bond0`）。

```text
              ┌────────── 同一 OVS bridge ──────────┐
  封装后发送 → underlay ──out──► bridge ──► 物理上行 → 对端 VTEP
                   │
                   └── 同桥再递送 ──► 业务口 ingress
```

对 OVS 而言两口只是同一台虚拟交换机上的端口，出口帧完全可能再出现在另一口上。

现场曾见（示例，不同环境数字会变）：

| 口 | access tag | ofport 例 |
|----|------------|-----------|
| 业务口 | 1001 | 1 |
| underlay | 1002 | 5 |
| 物理上行 bond | （多为 trunk） | 2 |

网关为 VRRP 时，外层目的 MAC 常为虚 MAC（如 `00:00:5e:00:01:02`）。  
FDB 可能在部分 VLAN 上学到该 MAC 并指向上行口；**underlay 所在 VLAN 若未学到，该 VLAN 上易按未知单播 flood**。  
业务口与 underlay VLAN 不同时，flood 是否「按规范」灌进业务口还可再抠；**不必纠结细节也能确认：同桥下业务口 ingress 确实能收到这份 VXLAN。**

---

## 3. 为何会放大成「怪波」

产品原先：

| 挂载点 | 自有 VXLAN dport 跳过 |
|--------|------------------------|
| 业务口 **egress** | 有 |
| 业务口 **ingress** | **无** |

于是：

```text
underlay 发出 VXLAN
  → 同桥进入业务口 ingress
  → handle_ingress 再次 clone
  → veth TBF → 再封装 → 再从 underlay 出
  → 再次回灌 …
  → 速率被 TBF 削成 ≈ rate 的平台（一阵一阵）
```

端口号（如 4790）自动下发一般没问题；问题在于 **回灌走 ingress，旧逻辑不防环**。  
4790 与 VXLAN-GPE 端口号重合只影响 tcpdump 解析提示，不是根因。

---

## 4. 产品侧修复

`agent-libs/driver/bpf/probe.c`：`handle_ingress` 与 egress 一样，先调用 `traffic_forwarding_should_skip_by_udp_dport()`，命中自有 VXLAN 端口则 **不 clone**，直接 `TC_ACT_OK`。

### 对接收端的影响

**接收端仍可正常收到。**

```text
跳过的是：业务口上「回灌进来的那份副本」的再次镜像
不跳过的是：本机已经从 underlay 正常发出的那份 VXLAN
```

- 对端 VTEP 路径不变：仍是 underlay → 线路 → 对端。  
- ingress 过滤不会 `SHOT` 掉 underlay 出站包。  
- 业务口上那份回灌帧只是不再进入采集管道；是否被本机协议栈丢掉/忽略与镜像无关。

### 残留限制

dport 识别已支持「以太头后直接 IPv4」以及 **单层 802.1Q/AD 后再跟 IPv4+UDP**。  
QinQ、IPv6、IP 分片非首片仍可能漏过滤，见 [`self-traffic-filter-vlan-and-fragments.md`](./self-traffic-filter-vlan-and-fragments.md)。

---

## 5. 如何确认（现场最小集）

```bash
ovs-vsctl port-to-br <业务口>
ovs-vsctl port-to-br <underlay口>
```

```bash
tcpdump -ni <underlay> -Q out udp port <vxlan端口> -c 30
tcpdump -ni <业务口> -Q in  udp port <vxlan端口> -c 30
tcpdump -ni <业务口> -Q out udp port <vxlan端口> -c 30
```

```text
同桥 + underlay out 有 + 业务口 in 有 + 业务口 out 无
→ 回灌成立
```

加载含 ingress 防环的 probe 后：业务口 in 仍可能看见回灌，但 TBF 满速平台 / 异常采集应明显收敛。

可选（桥侧兴趣）：

```bash
ip route get <VTEP>
tcpdump -ni <underlay> -Q out -e -c 5 udp port <vxlan端口> and dst host <VTEP>
ovs-appctl fdb/show <桥名> | grep -i <外层目的MAC>
ovs-vsctl get Port <underlay> tag
ovs-vsctl get Port <业务口> tag
```

---

## 6. 责任切分

| 层级 | 结论 |
|------|------|
| 同桥回灌 | 环境拓扑（业务口与 underlay 同 bridge） |
| 再次采集放大 | 产品：ingress 未防环（已修） |
| FDB/VLAN flood 细节 | 可解释 underlay VLAN 上为何易洪泛；不强制作为唯一桥侧故事 |

---

## 7. 一句话

> **同 OVS bridge 上，underlay 出口 VXLAN 会进业务口 ingress；旧逻辑再 clone 就被 TBF 塑成周期满速波。ingress 按自有 VXLAN 端口跳过即可打断放大，不影响对端正常收包。**
