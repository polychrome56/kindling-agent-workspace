# 流量转发文档（workspace）

本目录是协作仓内可提交的流量转发知识，配合 `.cursor/skills/traffic-forwarding/SKILL.md` 使用。

| 文档 | 内容 |
|------|------|
| [traffic-forwarding-path-evolution.md](./traffic-forwarding-path-evolution.md) | 拓扑代际演变总览 |
| [ovs-bridge-hairpin-mirror-amplification.md](./ovs-bridge-hairpin-mirror-amplification.md) | 同桥回灌与 ingress 防环 |
| [self-traffic-filter-vlan-and-fragments.md](./self-traffic-filter-vlan-and-fragments.md) | VLAN / 分片防环边界 |

更细的实现草案、压测笔记若只在本地 `agent-libs/docs/`，文中会标明「本地可选」；**本目录三篇为 workspace 真相源**。
