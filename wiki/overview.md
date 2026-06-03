# 总览：kas-radxa-dragon

_最后更新：2026-06-03_

## 这是什么

用 [kas](https://github.com/siemens/kas) 管理 **Radxa Dragon Q6A（Qualcomm QCS6490）** 的
Yocto/OpenEmbedded 构建的**集成仓库**。取代原先 `repo` + `setup_radxa_q6a` + `set_bb_env.sh`
的流程，把「拉哪些 layer、锁哪个版本、怎么配置构建」收敛到单一可版本化的 `kas-radxa-q6a.yml`。

- 仓库本身只存配置，不存 layer 源码。
- 基线：Qualcomm Linux **QLI.1.5-Ver.1.1**（Yocto `scarthgap`），对应原 manifest
  `qcom-6.6.90-QLI.1.5-Ver.1.1_qim-product-sdk-2.0.1.xml`。
- 远端：`git@github.com:CmST0us/kas-radxa-dragon.git`（分支 `main`）。

## 架构（三层）

沿用 LLM Wiki 的三层心智模型，落到本工程：

1. **真值来源（source of truth）**：`kas-radxa-q6a.yml` 与各 layer 的代码/配置。不可凭记忆改写。
2. **wiki**：本目录，人类可读的结构化说明，由 Claude 维护。见 [index](index.md)。
3. **schema**：仓库根的 `../CLAUDE.md`，规定 wiki 结构与「每次改动同步 wiki」的规约。

## 构建产物的两个正交维度

- **DISTRO** = `qcom-wayland`（全局策略：开启 wayland/vulkan/opengl）
- **IMAGE / target** = `qcom-multimedia-image`（具体镜像内容：带 Weston 的多媒体根文件系统）

详见 [distro-and-images](topics/distro-and-images.md)。

## 快速上手

```bash
pip install kas
cd /home/eki/Project/carbon/kas-radxa-dragon
kas build kas-radxa-q6a.yml
```

完整命令、缓存复用、本地开发模式见 [build-and-dev-workflow](topics/build-and-dev-workflow.md)。

## 相关页面

- [layers](components/layers.md) — 12 个 layer 的来源与锁定版本
- [machine-qcs6490-radxa-dragon-q6a](components/machine-qcs6490-radxa-dragon-q6a.md) — 机器配置与内核
- [driver-wifi-bt-aic8800d80](components/driver-wifi-bt-aic8800d80.md) — WiFi/BT 驱动与固件
- [kas-configuration](topics/kas-configuration.md) — kas 配置文件结构详解
- [versioning](topics/versioning.md) — 版本化策略
