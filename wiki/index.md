# Index — kas-radxa-dragon wiki

_最后更新：2026-06-06_

本知识库的内容目录。回答关于本仓库的问题时，先从这里定位页面。

## 入口
- [overview](overview.md) — 仓库总览、架构、快速上手
- [log](log.md) — 时间线（每次 change/decision/finding/lint）

## 外部参考资料（提炼）
- [qualcomm-linux.html](qualcomm-linux.html) — Qualcomm Linux 官方文档（Build Guide + Yocto Guide 全部子页面）深入提炼：layers / machine 配置链 / 构建路线 / 刷写 / 启动链·UKI·secure boot / 分区·OTA / 用户定制，并逐条映射到本项目 kas 做法

## Topics（概念：怎么做、为什么）
- [topics/kas-configuration](topics/kas-configuration.md) — `kas-radxa-q6a.yml` 结构详解（repos / layers / local_conf_header）
- [topics/build-and-dev-workflow](topics/build-and-dev-workflow.md) — 构建命令、缓存复用、本地开发模式、CI（GitHub Actions）
- [topics/versioning](topics/versioning.md) — layer 版本锁定、lockfile、本地↔远端切换
- [topics/distro-and-images](topics/distro-and-images.md) — `qcom-wayland` 与 `qcom-multimedia-image` 的区别与关系
- [topics/flashing](topics/flashing.md) — EDL 模式刷写固件：`edl-ng`（`scripts/flash-edl.sh`，只刷 LUN0/OS）与 `qdl`（全量 LUN0–5，含引导固件）

## Components（实体：具体的东西）
- [components/layers](components/layers.md) — 12 个 layer 的 URL / 锁定 commit / 角色
- [components/machine-qcs6490-radxa-dragon-q6a](components/machine-qcs6490-radxa-dragon-q6a.md) — 机器配置、内核、设备树
- [components/driver-wifi-bt-aic8800d80](components/driver-wifi-bt-aic8800d80.md) — AIC8800D80 WiFi/BT 驱动与固件
