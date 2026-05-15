---
name: kindling-project-map
description: 在编写、修改、重构或审查这个项目相关代码时，提供项目结构、模块职责和主要代码入口参考。Use when working on agent-libs, kindling/probe, eBPF, BPF map interaction, event wrapping, CGO, traffic forwarding, or other core modules.
disable-model-invocation: false
---

# Kindling 项目地图

这个 skill 用于在编写 `agent-libs` 与 `kindling/probe` 相关代码时，先快速建立项目分层、职责边界和阅读入口，避免一开始就把不同层的实现混在一起理解。

## 总体理解

- `agent-libs/`：偏底层能力，主要负责 eBPF 相关操作，例如 eBPF 挂载、BPF map 交互、事件读取与事件封装。
- `kindling/probe/`：probe 的用户态控制层，包含 CGO 相关边界，负责组织和驱动底层能力。
- `kindling/probe/src/core/`：核心功能实现区，按模块承载具体能力实现。
- `kindling/probe/src/core/traffic_forwarding/`：流量转发相关实现，重点关注模块职责、资源生命周期和模块间协作。

## 使用方式

当用户要求编写、修改、重构、解释或审查这个项目中的代码时，先做下面几步：

1. 先判断当前需求属于哪一层：
   - eBPF 挂载、map 读写、事件采集、内核侧交互：优先看 `agent-libs/`
   - probe 生命周期、用户态控制、CGO 边界：优先看 `kindling/probe/`
   - 某个具体功能模块实现：优先看 `kindling/probe/src/core/` 下对应目录
2. 先说明当前修改落在哪一层，再进入具体文件。
3. 如果问题跨层，先说清楚调用链和依赖方向，不要直接把边界揉平。

## 阅读与修改建议

- 先找已有相近模块和调用入口，再决定新增点放在哪一层。
- 不要把 `agent-libs` 和 `kindling/probe` 当成同一职责层；底层采集能力与用户态控制逻辑要分开描述。
- 处理 `core` 目录下模块时，先概括模块职责，再分析实现细节。
- 处理流量转发相关代码时，优先关注设备、转发路径、状态管理和错误传播。
- 如果涉及 eBPF 与用户态联动，优先梳理“挂载点 -> map 交互 -> 事件结构 -> 用户态封装”这条链路。

## 输出要求

- 先给分层判断，再给代码入口。
- 先讲职责边界，再讲实现细节。
- 如果改动落在 C/C++ 代码，同时遵守 `modern-cpp` 和 `cpp-engineering.mdc`。
- 如果涉及 BPF / tc / kernel-adjacent 代码，保持 verifier 友好、控制流简单，并保留错误上下文。
