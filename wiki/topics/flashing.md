# 刷写固件（edl-ng / EDL 模式）

_最后更新：2026-06-04_

脚本 `scripts/flash-edl.sh` 用 [edl-ng](https://dl.radxa.com/q6a/images/edl-ng-dist.zip) 在
Qualcomm EDL（9008）模式下刷写 Radxa Dragon Q6A。实现参考 flange 的
`builder/flash.py:QualcommFlashStrategy`，适配本工程的 Yocto 产物布局。

## 固件包来源（工程内，无本机路径）

SPI NOR 固件、UFS HLOS 镜像、firehose loader 全部取自 Radxa 官方固件包：

```
https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_wp_260120.zip
```

脚本首次运行（或 `fetch` 子命令）会自动下载并解压到 `scripts/firmware/`（已 gitignore），
之后在该目录内自动定位 `prog_firehose_ddr.elf`、`spinor` 与 `ufs_hlos`。
按[路径规则](../../CLAUDE.md)，脚本不引用任何工程外/本机路径。

## 两类刷写目标

| 子命令 | 目标 | 来源 |
|---|---|---|
| `spinor` | 引导固件（XBL/EDK2 等 SPI NOR） | 固件包 `spinor/` |
| `ufs` | 系统盘（HLOS 分区） | 固件包 `ufs_hlos/`；或 `UFS_DIR=` 指向 kas 自构建的 `deploy/images/<machine>` |

- **firehose loader** `prog_firehose_ddr.elf` 是板级签名 blob，不由本构建产出，随固件包获取。
- 系统盘走标准 QLI 分区刷写（`edl-ng --memory UFS rawprogram …`），不是 flange 的整盘
  `write-sector raw.img`——因为 Yocto/QLI 产出的是分区镜像 + rawprogram XML，而非单个 raw.img。

## 进入 EDL 模式

断电 → 按住 EDL 按钮 → 用 **USB3** 线连接主机上电。设备应枚举为
`Qualcomm HS-USB QDLoader 9008`（VID:PID `05c6:9008`，`lsusb` 可见）。

## 用法

```bash
# 在本仓库根目录执行
scripts/flash-edl.sh fetch       # 仅下载并解压固件包
scripts/flash-edl.sh detect      # 探测 EDL 设备
scripts/flash-edl.sh spinor      # 刷引导固件 (bring-up)
scripts/flash-edl.sh ufs         # 刷系统盘
scripts/flash-edl.sh all         # spinor → ufs → reset
scripts/flash-edl.sh reset       # 复位退出 EDL
```

USB 访问受限时：`SUDO=sudo scripts/flash-edl.sh …`（或配 udev 规则）。

## 关键环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `FW_URL` | Radxa `dragon-q6a_flat_build_wp_260120.zip` URL | 固件包下载地址 |
| `FW_DIR` | `scripts/firmware/` | 固件包下载/解压目录（gitignore） |
| `UFS_DIR` | 空 = 自动定位固件包内 `ufs_hlos` | 设为 `build/tmp-glibc/deploy/images/<machine>` 可刷 kas 自构建镜像 |
| `EDL_NG` | 空 | 显式指定 edl-ng 可执行文件，绕过自动定位 |
| `EDL_NG_URL` | Radxa `edl-ng-dist.zip` URL | edl-ng 自动下载地址 |

loader、spinor、ufs_hlos 目录均在 `FW_DIR` 内自动定位，无需手填路径。

**edl-ng 定位顺序**：`EDL_NG` 显式覆盖 → `scripts/edl-ng/`（已下载）→ PATH（如
`/usr/bin/edl-ng`）→ 自动下载到 `scripts/edl-ng/`。即系统已装则直接用，未装则自动拉取，
均不依赖工程外路径。

## edl-ng 命令对照（与 flange 一致的调用形态）

```
# 系统盘 / 引导固件（rawprogram）
edl-ng --loader prog_firehose_ddr.elf --memory <UFS|spinor> rawprogram <rawprogram*.xml> <patch*.xml>
# 复位
edl-ng reset
```

> 注：脚本把目录内所有 `rawprogram*.xml` 与 `patch*.xml`（按版本序）一并传入。若你的 edl-ng
> 需逐 LUN 成对调用，按 `rawprogramN.xml`+`patchN.xml` 循环即可（见脚本 `flash_rawprogram`）。
> UFS 出厂 provisioning（`flat_build/provision_*.xml`）有风险，脚本未纳入，按需另行处理。

## 相关
- [build-and-dev-workflow](build-and-dev-workflow.md) — 先 build 出 deploy/images
- [machine-qcs6490-radxa-dragon-q6a](../components/machine-qcs6490-radxa-dragon-q6a.md)
