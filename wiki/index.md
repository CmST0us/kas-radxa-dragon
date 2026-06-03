# Index — kas-radxa-dragon wiki

_最后更新：2026-06-03_

本知识库的内容目录。回答关于本仓库的问题时，先从这里定位页面。

## 入口
- [overview](overview.md) — 仓库总览、架构、快速上手
- [log](log.md) — 时间线（每次 change/decision/finding/lint）

## Topics（概念：怎么做、为什么）
- [topics/kas-configuration](topics/kas-configuration.md) — `kas-radxa-q6a.yml` 结构详解（repos / layers / local_conf_header）
- [topics/build-and-dev-workflow](topics/build-and-dev-workflow.md) — 构建命令、缓存复用、本地开发模式
- [topics/versioning](topics/versioning.md) — layer 版本锁定、lockfile、本地↔远端切换
- [topics/distro-and-images](topics/distro-and-images.md) — `qcom-wayland` 与 `qcom-multimedia-image` 的区别与关系

## Components（实体：具体的东西）
- [components/layers](components/layers.md) — 12 个 layer 的 URL / 锁定 commit / 角色
- [components/machine-qcs6490-radxa-dragon-q6a](components/machine-qcs6490-radxa-dragon-q6a.md) — 机器配置、内核、设备树
- [components/driver-wifi-bt-aic8800d80](components/driver-wifi-bt-aic8800d80.md) — AIC8800D80 WiFi/BT 驱动与固件
