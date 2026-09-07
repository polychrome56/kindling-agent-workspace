---
name: traffic-forwarding
description: >-
  流量转发（镜像）路径、设备角色、防环与常见故障排查指引。
  Use when working on traffic forwarding, traffic_forwarding, VXLAN mirror,
  TBF pacing, veth.kindling, dummy.kindling, self-traffic skip, hairpin,
  underlay, or related BPF/TC clone_redirect paths.
disable-model-invocation: false
---

# 流量转发（镜像）

先建立路径与职责，再改代码或排障。细节长文在 `agent-libs/docs/`，本 skill 只给骨架与入口。

分层总览仍看 `kindling-project-map`；BPF/tc 硬约束看 `.cursor/rules/agent-libs/bpf-kernel-tc-conventions.mdc`。

## 用语

| 用语 | 含义 |
|------|------|
| 目标网卡 | 采集/镜像口，挂 TC-BPF |
| underlay 网卡 | VXLAN 外层真正发出去的网卡 |
| 自有设备 | 产品创建的 `dummy` / `veth_*` / `vxlan.kindling` 等 |

## 当前主路径（第③代）

```text
目标网卡 TC（ingress/egress）
  → bpf_clone_redirect（flag=0，走 egress）
  → veth_a.kindling（root TBF 削峰）
  → veth_b.kindling（landing BPF：流表恢复来源 → redirect VXLAN）
  → vxlan.kindling（egress 设 tunnel key / 多接收端）
  → underlay 网卡
```

代际简述：

1. 目标网卡 → `vxlan`：能镜像，但同步拖死业务 CPU  
2. → `dummy`（`BPF_F_INGRESS`）：异步解耦，但 dummy 难挂 qdisc  
3. → `veth_a/b` + TBF：**现状主路径**，自有设备削峰  
4. → `dummy` + `veth`：设计中，异步边界 + 削峰  
5. `veth_b` 空 `XDP_PASS`：验证中，补 headroom，降 `vxlan tx_errors`

## 代码入口（优先顺序）

1. BPF helpers / 防环 / clone：`agent-libs/driver/bpf/traffic_forwarding_helpers.h`、`probe.c` 中 ingress/egress handler  
2. 用户态设备与生命周期：`kindling/probe/src/core/traffic_forwarding/`（含 `virtual_device`）  
3. CGO / 服务编排：`kindling/collector/.../cgoreceiver/` 下 traffic forwarding 相关  

改 BPF 时：局部变量使用处声明或带初始值；控制流简单、有界；不要仅为声明变量套多余 `{}`。

## 防环（必查）

- 自有 VXLAN UDP dport 命中则 **不** `clone_redirect`（避免把外层自流量再镜像一遍）。  
- **egress 与 ingress 都要 skip**；只做 egress 时，同桥 hairpin 回灌会在业务口 ingress 再采集 → 吞吐被 TBF 卡住的平台期。  
- 解析：以太后可选 **单层** 802.1Q/AD，再认 IPv4+UDP+dport（`tf_parse_eth_l3`）。QinQ 仍可能漏过滤。  
- IP 分片**非首片**：`self_frags` LRU map 连坐 skip（软 TTL 2s）。禁止全局 skip 所有分片。  
- **采集口若含自有 underlay**（或同桥回灌）：后续片漏过滤会「再封装再分片」反馈环；详见防环长文 §5.2。  
- skip 只停「再镜像」；远端 VTEP 仍收正常 underlay 发出的 VXLAN。

## 排障顺序（一次只改一个变量）

1. **平台期 ≈ TBF 速率**：先怀疑自流量回灌 / 防环缺口，而不是盲目加带宽。对照 underlay out 与目标网卡 in 是否同五元组 VXLAN。  
2. **`vxlan.kindling` `tx_errors`**：常见是 clone skb 缺 headroom → `vxlan_build_skb` / `pskb_expand_head` 失败。与「镜像限速丢包」分开看。  
3. **业务 UDP 丢 / TCP 重传升、整机 CPU 不高**：优先看目标网卡 CPU 上同步 clone 成本（历史第①代问题；第③代仍可能把成本挪到业务路径附近）。  
4. 观测优先于调参：`ip -s link`、`tc -s qdisc`、必要时 kprobe/`bpftrace`；不要一次改 GSO+MTU+TBF。

## 长文入口（本仓可提交）

- [`docs/traffic-forwarding/traffic-forwarding-path-evolution.md`](../../../docs/traffic-forwarding/traffic-forwarding-path-evolution.md) — 拓扑演变总览  
- [`docs/traffic-forwarding/ovs-bridge-hairpin-mirror-amplification.md`](../../../docs/traffic-forwarding/ovs-bridge-hairpin-mirror-amplification.md) — 同桥回灌与 ingress skip  
- [`docs/traffic-forwarding/self-traffic-filter-vlan-and-fragments.md`](../../../docs/traffic-forwarding/self-traffic-filter-vlan-and-fragments.md) — 自流量防环：VLAN + 分片 map 技术说明  

目录索引见 [`docs/traffic-forwarding/README.md`](../../../docs/traffic-forwarding/README.md)。更细的压测/草案若只在本地 `agent-libs/docs/`，以文中「本地可选」标注为准。

## 输出要求

- 先说当前落在哪一段路径（采集 / 整形 / landing / VXLAN / underlay / 防环）。  
- 跨层时先画调用方向，再改具体文件。  
- 方案对比时区分「已落地 / 验证中 / 设计中」，并点明会伤业务还是只伤镜像副本。
