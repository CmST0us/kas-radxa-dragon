# DISTRO 与 IMAGE（qcom-wayland vs qcom-multimedia-image）

_最后更新：2026-06-03_

构建的两个**正交维度**，必须同时指定，各管一摊。

## qcom-wayland —— DISTRO（发行版策略）

定义全局策略，影响**每一个**被编译的包。`meta-qcom-distro/conf/distro/qcom-wayland.conf`：
```
require conf/distro/include/qcom-base.inc
DISTRO_FEATURES:append = " wayland vulkan opengl"
```
即 = qcom 基础发行版 + 启用 wayland/vulkan/opengl 图形栈。本身**不产出镜像**。
（该 layer 仅此一个 distro 可选。）

## qcom-multimedia-image —— IMAGE（构建目标）

决定最终镜像里装哪些包。继承链：
```
qcom-minimal-image            最小可启动 rootfs
  └─ qcom-console-image       + 包管理 / SSH / packagegroup-qcom
       └─ qcom-multimedia-image   + packagegroup-qcom-multimedia（Weston）
```
关键：`REQUIRED_DISTRO_FEATURES += "wayland"` —— 这正是它必须配 `qcom-wayland` 的原因。

## 对照

| | qcom-wayland | qcom-multimedia-image |
|---|---|---|
| 维度 | DISTRO（怎么编） | IMAGE（装什么） |
| kas 字段 | `distro:` | `target:` |
| 范围 | 全局所有包 | 仅镜像内容 |
| 产物 | 无 | `.rootfs` 镜像 |

## 可选 target

`qcom-console-image`、`qcom-minimal-image`、`qcom-multimedia-test-image`、`qcom-x11-image` 等。
想要无图形精简系统可把 target 换成 console/minimal，distro 仍可保持 qcom-wayland。

## 相关
- [kas-configuration](kas-configuration.md)
- [machine-qcs6490-radxa-dragon-q6a](../components/machine-qcs6490-radxa-dragon-q6a.md)
