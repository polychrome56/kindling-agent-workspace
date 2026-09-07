# 自流量防环加强：VLAN 解析与 IP 分片

> **位置**：workspace 仓 `docs/traffic-forwarding/`。  
> 关联：[`ovs-bridge-hairpin-mirror-amplification.md`](./ovs-bridge-hairpin-mirror-amplification.md)、  
> [`traffic-forwarding-path-evolution.md`](./traffic-forwarding-path-evolution.md) §6  
> 状态：**VLAN 单层解析已落地**（`tf_parse_eth_l3` + `traffic_forwarding_should_skip_by_udp_dport`）。  
> IP 分片状态表尚未落地。当前可跳过：无 VLAN 或单层 802.1Q/AD 后的完整 IPv4+UDP，且 dport 在自有 VXLAN 端口表中。

---

## 1. 目标

在「自有 VXLAN / 回灌自流量」上尽量不二次 clone，同时 **尽量不误伤本应采集的业务流量**。

当前跳过逻辑（`traffic_forwarding_should_skip_by_udp_dport`）能力边界：

| 已覆盖 | 未覆盖 |
|--------|--------|
| 以太 → IPv4 → UDP → dport∈自有端口表 | 分片**非第一片**（无 UDP 头） |
| 以太 → **单层 802.1Q/AD** → IPv4 → UDP → dport∈表 | QinQ（两层 VLAN） |
| 完整包 / 分片**第一片**（带 UDP 头） | 外层 IPv6 |

---

## 2. 加强项 A：单层 802.1Q / 802.1AD 解析

### 2.1 含义

不是产品「VXLAN 之后再封一层 VLAN」，而是 TC 看到的帧可能是：

```text
[以太][802.1Q 或 802.1AD][IP][UDP][VXLAN]…
```

VLAN 来自 OVS access/trunk、交换机等。只认「以太后直接是 IP」时，带 tag 的自有 VXLAN 会漏过滤；现已剥一层 tag 再认 dport。

### 2.2 已落地行为

```text
读 ethertype
  → 若为 0x8100（Q）或 0x88a8（AD）：跳过 4 字节 VLAN 头（只剥一层）
  → 再按现有逻辑认 IPv4 + UDP + dport
```

实现：`tf_parse_eth_l3()`，自流量防环与流表五元组解析共用。  
「单层」：只跳一次 VLAN 头；QinQ 仍可能认不出。

### 2.3 什么时候 TC 会看到 VLAN？

**不是** Kindling 在 VXLAN 外面再封一层 VLAN。tag 来自二层设备/口配置。常见情况：

| 场景 | TC 看到的帧 |
|------|-------------|
| 采集口是 **access**（OVS `tag=N`） | 主机侧常是**裸以太网**（无 802.1Q）；进桥后才带 VLAN |
| 采集口是 **trunk** / 子接口 `vlan.N@eth` | 线上常是 **以太 + 802.1Q + IP** |
| 同桥回灌打到 **trunk 业务口** | 回灌的自有 VXLAN 可能带着 tag |
| 交换机/物理口本身打 tag | 同样是外层 802.1Q/AD |

因此：access 口上防环「无 VLAN 也能认」仍然有效；**trunk / VLAN 子接口 / tagged 回灌** 才需要这次剥 tag。

### 2.4 误伤风险

**低。** 只改变「能不能认出端口」；认出且命中自有 VXLAN 端口才 skip。  
业务 VLAN 里的普通 TCP/UDP **不会**仅因剥了 tag 就被跳过。

---

## 3. 加强项 B：IP 分片

### 3.1 为何会分片

```text
大包 →（可选 GSO）→ 加 VXLAN/UDP/IP
  → 外层仍可能 > underlay MTU
  → IP 分片
```

- **第一片**：含 UDP/VXLAN 头 → 现有 dport 可跳过  
- **后续片**：IP 头里 `protocol` 仍是 UDP，但载荷开头**不是** UDP 头 → 现有逻辑无法按 dport 判断 → **会漏过滤，可能再次 clone**

### 3.2 会不会过滤掉「本身要采集的流量」？

取决于怎么写策略。

#### 错误做法：凡是分片都 skip

```text
所有 IPv4 分片（或所有非首片）一律不 clone
```

**会误伤。** 业务口上合法的大 UDP/其它分片流量，后续片也会被丢掉采集，镜像不完整，`collected_bytes` 也会偏少。

#### 错误做法：凡是 protocol=UDP 的非首片都 skip

同样太宽：业务 UDP 分片后续片也会被跳过。

#### 推荐做法（精确、稍复杂）

只跳过「属于自有 VXLAN 的那串分片」：

```text
1. 首片：能解析 UDP 且 dport∈自有 VXLAN 表 → skip，并记下
   key ≈ (src, dst, protocol, id)［短 TTL map］
2. 后续片：同 key → 一并 skip
3. 其它分片：照常走采集（允许 clone）
```

这样：

| 流量 | 结果 |
|------|------|
| 自有 VXLAN 首片 + 后续片 | 都跳过，防环 |
| 业务 UDP/TCP 分片 | **仍采集**（不进上述 key） |
| 业务完整包 | 不变 |

#### 更稳的治本（优先）

少产生外层分片：隧道 GSO / 控制段长，使外层 ≤ underlay MTU。  
分片变少后，防环大多只需处理「带 UDP 头」的包，盲区自然缩小。

### 3.3 和「接收端能不能收到」的关系

- **对端收你们的镜像 VXLAN**：防环 skip 的是「不要再采自有隧道」；不挡住 underlay 正常出站。  
- **你们采集业务分片**：若用「精确 key」方案，业务分片仍会进管道；若用「一律跳过非首片」，业务侧镜像会缺后续片。

---

## 4. 建议落地顺序

```text
1. VLAN 单层解析（误伤低、实现简单）→ **已做**
2. 减少外层 IP 分片（GSO/MTU）→ 治本，降低对分片防环的依赖
3. 自有 VXLAN 分片状态表（首片记 key，后续片连坐 skip）→ 需要再评估 map 容量与老化
4. 禁止「全局 skip 所有分片」→ 避免误伤业务采集
```

---

## 5. 验收要点

- 带一层 802.1Q 的自有 VXLAN：ingress/egress 均不再二次 clone（**已实现**）。  
- 业务 VLAN 内普通流量：采集量与改前一致。  
- 制造外层 IP 分片的自有 VXLAN：首片 + 后续片均不被再次 clone（若已上状态表）。  
- 业务大 UDP 分片：后续片仍会被 clone（镜像侧可重组或接受分片形态）。  
- 对端 VTEP 仍能稳定收到镜像流。

---

## 6. 一句话

> **VLAN：剥一层 tag 再认 VXLAN 端口，几乎不误伤业务。**  
> **分片：不能一刀切 skip；只对「已确认为自有 VXLAN 的分片链」跳过，否则会丢掉要采的业务分片。优先少分片，再上精确防环。**
