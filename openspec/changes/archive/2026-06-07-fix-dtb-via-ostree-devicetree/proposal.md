## Why

Radxa Dragon Q6A 当前启动时，内核拿到的设备树（dtb）是 **UEFI 固件内嵌的旧 stock dtb**，而不是本工程构建出的正确 dtb。后果：USB（`snps-dwc3` 无驱动）、GPU、VPU、display 全部失效。

根因已查清（见 `wiki/log.md` 2026-06-06 多条 finding）：

- 启动链是 UEFI → systemd-boot → OSTree 管理的 type-1 启动条目 `ostree-1.conf` → 内核（EFI-stub）。
- 该条目**没有 `devicetree` 行**，cmdline 也没有 `dtb=`，于是内核 EFI-stub 从「EFI 配置表」取树 —— 而配置表里是 UEFI 写死内嵌的旧 dtb。
- 这版 UEFI 是预编译签名 blob、不读 dtb 分区、无法重编，所以**不能从固件侧修**；只能在启动条目里把正确 dtb 喂给内核。

本提案用 OSTree 自带的机制做这件事：打开 `OSTREE_DEPLOY_DEVICETREE`，让 OSTree 把正确 dtb 部署进启动目录，并在 `ostree-1.conf` 里自动写出 `devicetree` 行覆盖固件内嵌树。

## What Changes

分两步推进，第一步验证机制、第二步补全设备：

- **Step 1 — 打开开关、验证链路通**：设 `OSTREE_DEPLOY_DEVICETREE = "1"`，`OSTREE_DEVICETREE` 暂用默认值（裸的 `qcs6490-radxa-dragon-q6a.dtb`，已在 `DEPLOY_DIR_IMAGE`）。目标：构建后启动条目长出 `devicetree` 行、刷机后 USB 恢复（board-id/msm-id 生效）。此步 GPU/VPU 可能仍未恢复（裸 dtb 缺 graphics/video 叠加）。
- **Step 2 — 指向完整 dtb、修好 GPU/VPU/display**：把 `OSTREE_DEVICETREE` 指向 `combined-dtb.dtb`（已合并 `qcm6490-graphics.dtbo` + `qcm6490-video.dtbo` 的完整树），并给 `linux-qcom-mergedtb` 配方补 `do_deploy`，把 `combined-dtb.dtb` 投到 `DEPLOY_DIR_IMAGE`，使 `ostree-kernel-initramfs` 能拷到它。
- **板级改动落点**：machine 配置与 `linux-qcom-mergedtb` 配方的改动放进**本地副本 `../meta-radxa-dragon`**，并把 kas 从远端锁定模式切回本地开发模式（`path: ../meta-radxa-dragon`）以便迭代。
- **构建分工**：所有 `kas build` / `bitbake` 由用户本人执行，本提案与实施过程不代为执行构建。

## Capabilities

### New Capabilities

- `boot-devicetree`: 规定本机启动链如何选择并交付内核设备树 —— 由 OSTree/systemd-boot 启动条目显式指定正确 dtb，覆盖 UEFI 固件内嵌的 stock dtb。

### Modified Capabilities

（无既有 spec 需修改 —— `openspec/specs/` 当前为空。）

## Impact

- **kas 配置 `kas-radxa-q6a.yml`**：`meta-radxa-dragon` 由远端锁定切回本地 `path: ../meta-radxa-dragon`；`local_conf_header` 可临时承载 Step 1 的开关验证。
- **本地副本 `../meta-radxa-dragon`**：
  - `conf/machine/qcs6490-radxa-dragon-q6a.conf` —— 新增 `OSTREE_DEPLOY_DEVICETREE` / `OSTREE_DEVICETREE` 设置。
  - `recipes-kernel/images/linux-qcom-mergedtb.bb` —— 新增 `do_deploy`，部署 `combined-dtb.dtb` 到 `DEPLOY_DIR_IMAGE`。
- **构建产物**：OTA sysroot 的 `ostree-1.conf` 新增 `devicetree` 行；启动目录新增部署的 dtb 文件。仅影响**新部署**，需重新构建并刷机才生效。
- **依赖链**：`ostree-kernel-initramfs` 的 dtb 拷贝依赖 `linux-qcom-mergedtb:do_deploy` 先完成（Step 2 引入）。
- **wiki**：提案完成后回填 `topics/flashing.md`、`components/machine-qcs6490-radxa-dragon-q6a.md`，并在 `log.md` 追加记录。
- **风险/回滚**：纯配置与启动条目改动，可逆；单条目误改不启动时用 EDL 兜底重刷。
