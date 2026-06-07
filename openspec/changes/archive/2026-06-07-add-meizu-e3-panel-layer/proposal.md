## Why

Radxa Dragon Q6A（QCS6490）当前固件不支持外接魅族 E3 39pin MIPI-DSI 屏（显示 + 触摸 + 背光）。该屏在 mainline drm/msm 栈下没有通用 DSI panel 驱动可用，且 QCS6490 启动链不支持运行时 dtb overlay，必须在构建期把面板适配编进固件。本变更提供一个**可选、可组合**的 meta 层，让用户按需叠加面板支持，不影响基线固件。

## What Changes

- 新建自包含 meta 层 `meta-mipi-panel`，提供魅族 E3 屏的三块驱动与设备树叠加：
  - 显示：OOT 驱动 `panel_meizu_e3`（`compatible = "meizu,e3-panel"`）；
  - 触摸：OOT 驱动 `sec_ts`（固件 `.i` 已 `#include` 进 `.ko`，无需单独固件包）；
  - 背光：OOT 驱动 `sgm37604a`（I2C 背光芯片）；
  - 设备树：`qcom-qcs6490-radxa-dragon-q6a-meizu-e3-panel.dtso` 编成 `meizu-e3-panel.dtbo`。
- 驱动源码与 `.dtso` 从外部参考工程（flange `meizu-e3-panel` 包）**拷入本 layer 自包含**，不跨工程引用（遵守 CLAUDE.md 路径规约）。
- 复用现有 DTB 合并管线：把 `meizu-e3-panel.dtbo` 登记进 `KERNEL_TECH_DTBOS`，由现成的 `linux-qcom-mergedtb` 合进 `combined-dtb.dtb`，再经现有 `OSTREE_DEPLOY_DEVICETREE` 机制带进固件。不新增合并机制、不改 `linux-qcom-mergedtb` 配方源（dtbo 登记用本层的 bbappend 增广 varflag）。
- 接线（dtbo 登记、provider 登记、镜像装包、模块自动加载）全部放在本层（`conf/layer.conf` + bbappend），用 machine override 收口到 `qcs6490-radxa-dragon-q6a`，做到「包含 layer = 启用面板」。
- **板级能力另置**：i2c GENI SE 固件 `qupv3fw.elf`（rootfs `/lib/firmware/`）是板级基础能力（任何声明 `qcom,load-firmware` 的 SE 都需要），故新增配方 `qcom-qupv3fw-rootfs` 放在板层 `meta-radxa-dragon`、经其机器配置 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS` 进镜像（与 wifibt-firmware 同性质），不放在面板层。
- 新建 kas 片段 `meizu-e3-panel.yml`（只负责加 `meta-mipi-panel` 这一个 layer），使 `kas build kas-radxa-q6a.yml:meizu-e3-panel.yml` 组合出带屏固件。

## Capabilities

### New Capabilities
- `meizu-e3-panel`: 魅族 E3 MIPI-DSI 屏（显示/触摸/背光）在 Radxa Dragon Q6A 上的固件适配能力——以独立 meta 层提供三块 OOT 驱动与设备树叠加，并通过现有 DTB 合并与部署管线进入固件；以 kas 片段实现可选组合。

### Modified Capabilities
- 无。本变更复用 `boot-devicetree` 能力的现有机制（`combined-dtb.dtb` 合并与部署），但不改变其任何 Requirement。

## Impact

- **新增文件（本仓库）**：kas 片段 `meizu-e3-panel.yml`。
- **新增 layer（同级本地，仿 `meta-radxa-dragon` 约定）**：`../meta-mipi-panel`，含 `conf/layer.conf` 与单一配方 `meizu-e3-panel_1.0.bb` 及其 `files/`（三套驱动源 + 根 Makefile + `.dtso`）。
- **改动 `meta-radxa-dragon`（板层，有意）**：新增 `recipes-bsp/qup-firmware/qcom-qupv3fw-rootfs_1.0.bb`，并在机器配置 `qcs6490-radxa-dragon-q6a.conf` 加一行 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS`。
- **复用、不改动**：`meta-radxa-dragon` 的 `linux-qcom-mergedtb` 配方源、`OSTREE_DEPLOY_DEVICETREE` 部署链均保持原样（dtbo 登记走本层 bbappend，不碰 mergedtb 源）。
- **构建产物**：`combined-dtb.dtb` 在叠加面板 dtbo 后多出面板相关节点；镜像多出三个 `.ko`。
- **基线不受影响**：不组合 `meizu-e3-panel.yml` 时，构建与现状完全一致。
- **wiki**：变更完成后需在 `wiki/` 新增页面并在 `wiki/log.md` 追加记录。
