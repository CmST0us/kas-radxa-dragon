## ADDED Requirements

### Requirement: 启动条目显式指定设备树

系统 SHALL 在 OSTree 生成的 systemd-boot type-1 启动条目（`ostree-1.conf`）中写出 `devicetree` 行，使内核启动时使用本工程部署的 dtb，而非 UEFI 固件内嵌的 stock dtb。

为此，构建配置 MUST 设 `OSTREE_DEPLOY_DEVICETREE = "1"`，使 `ostree-kernel-initramfs` 将 `OSTREE_DEVICETREE` 指定的 dtb 部署到 `/usr/lib/modules/<ver>/devicetree`，并由 libostree 在部署时写出启动条目的 `devicetree` 行。

#### Scenario: 启动条目包含 devicetree 行

- **WHEN** 以 `OSTREE_DEPLOY_DEVICETREE = "1"` 构建 OTA 镜像
- **THEN** OTA sysroot 的 `boot/loader/entries/ostree-1.conf` 中存在 `devicetree` 行，且指向已部署的 dtb 文件

#### Scenario: 内核使用部署的设备树而非固件内嵌树

- **WHEN** 刷入新构建镜像并启动设备
- **THEN** 运行中内核的 `/sys/firmware/fdt` 内容与本工程部署的 dtb 一致，而非 UEFI 内嵌的 stock dtb

### Requirement: 设备树须为合并 graphics/video 叠加后的完整树

系统部署给内核的设备树 MUST 是经 `linux-qcom-mergedtb` 合并 `qcm6490-graphics.dtbo` 与 `qcm6490-video.dtbo` 后的 `combined-dtb.dtb`，而非未叠加的裸 `qcs6490-radxa-dragon-q6a.dtb`，以保证 GPU（zap shader）与 VPU（venus）节点齐全。

为此，`OSTREE_DEVICETREE` MUST 指向 `combined-dtb.dtb`，且该文件 MUST 可在 `DEPLOY_DIR_IMAGE` 中被 `ostree-kernel-initramfs` 取到。

#### Scenario: 部署的设备树带齐 USB/GPU/VPU 节点

- **WHEN** 以 `OSTREE_DEVICETREE = "combined-dtb.dtb"` 构建并刷机
- **THEN** 设备的 USB（`qcom,dwc3`）、GPU（带 zap shader 绑定）、VPU（venus）均正常工作

#### Scenario: combined-dtb 可被部署流程取到

- **WHEN** 构建执行到 `ostree-kernel-initramfs` 的 dtb 拷贝步骤
- **THEN** `combined-dtb.dtb` 已由 `linux-qcom-mergedtb:do_deploy` 投放到 `DEPLOY_DIR_IMAGE`，拷贝不因文件缺失而失败

### Requirement: 板级改动落于本地副本且不代为执行构建

本提案的 machine 配置与 `linux-qcom-mergedtb` 配方改动 MUST 落入本地副本 `../meta-radxa-dragon`，kas 配置须切回本地开发模式（`path: ../meta-radxa-dragon`）。所有 `kas build` / `bitbake` 构建 MUST 由用户本人执行，实施过程不得代为执行构建。

#### Scenario: kas 解析到本地副本

- **WHEN** 执行 `kas dump kas-radxa-q6a.yml`
- **THEN** `meta-radxa-dragon` 解析为本地 `path: ../meta-radxa-dragon`，而非远端锁定的 commit

#### Scenario: 构建由用户执行

- **WHEN** 实施进行到需要构建验证的环节
- **THEN** 实施方仅给出待执行的构建命令并交由用户运行，不自行执行 `kas build` 或 `bitbake`
