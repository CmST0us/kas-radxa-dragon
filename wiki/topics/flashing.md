# 刷写固件（EDL 模式：edl-ng 或 qdl）

_最后更新：2026-06-06_

两条刷写路径，都在 Qualcomm EDL（9008）模式下工作：
- **edl-ng**：脚本 `scripts/flash-edl.sh` 用 [edl-ng](https://dl.radxa.com/q6a/images/edl-ng-dist.zip)，
  实现参考 flange 的 `builder/flash.py:QualcommFlashStrategy`，适配本工程的 Yocto 产物布局。
  以**单次合并调用**形态可写**全部 LUN0–5**（含引导固件）——见下文 LUN 布局。日常系统更新、
  换板/bring-up 都可用。
- **qdl**（mainline，本机 `/usr/bin/qdl`）：同样能写**全部 LUN0–5**，作为已验证的备选手动手段。
  见下文 [用 qdl 全量刷写](#用-qdl-全量刷写lun05推荐用于换板bring-up)。

> **一句话结论**：无论 edl-ng 还是 qdl，**把全部 rawprogram + patch 一次性合并传入**即可写全 LUN；
> 逐 LUN 分开调用会让 LUN1-5 被 NAK（曾长期误判为「设备只接受 LUN0」）。

## 固件包来源（工程内，无本机路径）

SPI NOR 引导固件与 firehose loader 取自 Radxa 官方 **LE/QCLINUX** flat_build：

```
https://dl.radxa.com/dragon/q6a/images/dragon-q6a_flat_build_251013.zip
```

脚本首次运行（或 `fetch` 子命令）会自动下载并解压到 `scripts/firmware/`（已 gitignore），
之后在该目录内自动定位 `prog_firehose_ddr.elf` 与 `spinor`。
按[路径规则](../../CLAUDE.md)，脚本不引用任何工程外/本机路径。

> **UFS 系统盘不用这个包**：`ufs` 刷的是 kas 自构建镜像（`…/qcom-multimedia-image`），
> 此包只提供 `spinor` 引导固件与 loader。

## ⚠ SPI 引导固件必须是 LE/QCLINUX 套件，不能用 wp_*(Windows)

Radxa 为 Dragon Q6A 同时发两套 flat_build，**SPI 引导固件互不兼容**，区别是目标 OS
（2026-06-06 逐文件比对 `251013` 与 `wp_260120` 两套 spinor 确认）：

| | `dragon-q6a_flat_build_251013`（**用这套**） | `dragon-q6a_flat_build_wp_260120`（**别用**） |
|---|---|---|
| `contents.xml` 产品 | `QCM6490.`**`LE`**`.1.0`（Linux Embedded） | `QCM6490.`**`WP`**`.1.0`（Windows Platform） |
| HLOS | `LE.QCLINUX.1.0.r1`（Qualcomm Linux） | Windows-on-ARM（`<windows_root_path>`） |
| XBL/UEFI 变体 | `SocKodiakLAA` / `BOOT.MXF.1.0.c1-00364-KODIAK`**`LA`**`-1` | `SocKodiakWP` / `BOOT.MXF.1.0.1-00549-KODIAK`**`WP`**`-1` |
| HYP | `hypvm.mbn`(1.5MB)=**Gunyah**（Linux 主 VM，`gunyah-… prod`） | `hyp.mbn`(427KB)=Windows 用 hyp |
| DEVCFG | `devcfg.mbn` | `devcfg_windows_hyp_rfcomm.mbn` |
| UEFI 交接 | 独立 `uefi.elf`，内含 FDT 机制（`SecFdtInitRootHandle`/`fdt_header`），发**设备树** | `PILFV.Fv`（WoA PI 固件卷），发 **ACPI+SMBIOS** |
| 专有分区 | `UEFI` / `FATTEST` | `VarStore`/`SMBIOS`/`PILFv`/`TZAPPS`/`DPP`/`SSD`/`SD_MGR` |
| TZ / AOP 基线 | TZ.XF **5.29** / AOP HO.3.6 **KODIAK** | TZ.XF **5.11** / AOP HO.3.0 **LAHAINA** |

本仓库 kas 构建出的是 **Qualcomm Linux（QCLINUX/LE）HLOS**：UKI **不内嵌 dtb**
（[`linux-qcom-uki.bb`](../../layers/meta-qcom-hwe/recipes-kernel/images/linux-qcom-uki.bb) 无 `--dtb`），
内核的设备树**全靠 UEFI 提供**，且作为 **Gunyah 主 VM** 运行。若 SPI 烧的是 WP(Windows) 引导固件：

1. WP UEFI 出 ACPI/SMBIOS、不出设备树 → 内核拿不到 DT、连 GENI UART（`0x00994000`）都找不到
   → **连 earlycon 都零输出**；
2. WP hyp 给 Windows guest 配 EL2，Linux 期望的 Gunyah 主 VM 环境不存在
   → **EL2 异常 → 热复位入 dload**。

这正是 bring-up 时「**全量刷 UFS 仍不启动**」的真因——`scripts/flash-edl.sh ufs`（含 LUN0-5）
**只换 UFS LUN，SPI NOR 的 Windows 引导栈一直在**，直到把 LE 套件的 spinor 刷进 SPI 才配套。
**与版本新旧无关**（WP 的 boot 版本 `00549` 反而比 LE 的 `00364` 更新）。

防呆：`flash-edl.sh` 的 `FW_URL` 默认已指向 LE 包；`spinor` 子命令若在固件目录里发现
`PILFV.Fv`/`devcfg_windows_hyp*`/`hyp.mbn` 等 WP 特征会**直接拒刷**并提示清缓存重取。

## 两类刷写目标

| 子命令 | 目标 | 来源 |
|---|---|---|
| `spinor` | 引导固件（XBL/EDK2 等 SPI NOR） | 固件包 `spinor/`（单 LUN0） |
| `ufs` | 系统盘 LUN0（`efi` + `system` 即 OS） | kas 自构建 `deploy/images/<machine>/qcom-multimedia-image/`（自动定位） |

- **UFS 镜像目录**自动定位到 `build/tmp-glibc/deploy/images/<machine>/qcom-multimedia-image/`。
  该子目录才是自洽的整套刷写集（重命名后的 `system.img`/`efi.bin`/`dtb.bin` + `rawprogram<N>.xml`
  + 同目录 `prog_firehose_ddr.elf`）。**deploy 根目录**虽也有 `rawprogram<N>.xml`，却缺这些重命名
  镜像，不能直接刷。可用 `UFS_DIR=` 显式覆盖。
- **firehose loader** `prog_firehose_ddr.elf`：ufs 优先用镜像目录内同版本的；spinor 用固件包内的。
- 系统盘走标准 QLI 分区刷写（`edl-ng --memory UFS rawprogram …`），不是 flange 的整盘
  `write-sector raw.img`——因为 Yocto/QLI 产出的是分区镜像 + rawprogram XML，而非单个 raw.img。

### UFS 的 LUN 布局（LUN1-5 的 NAK 源于「逐 LUN 分开调用」，合并调用即可写）

QLI 的 UFS 分 6 个 physical_partition（LUN 0–5），每个一对 `rawprogram<N>.xml` + `patch<N>.xml`：

| LUN | 内容 | 逐 LUN 分开调用 | 单次合并调用 |
|---|---|---|---|
| **0** | `efi`（ESP，含 UEFI/内核）+ `system`（rootfs）+ GPT —— **即 OS** | ✅ 可写 | ✅ 可写 |
| 1 | `xbl_a` / `xbl_config_a`（UFS **boot LUN A**） | ❌ NAK | ✅ 可写 |
| 2 | `xbl_b`（UFS **boot LUN B**） | ❌ NAK | ✅ 可写 |
| 3 | 小固件分区 | ❌ NAK | ✅ 可写 |
| 4 | `aop`/`dtb`/`uefi`/`tz`/`hyp`/`devcfg`/… 共 ~926MiB | ❌ NAK | ✅ 可写 |
| 5 | 小固件分区 | ❌ NAK | ✅ 可写 |

**根因（2026-06-06 实测确定）**：先前以为本板 `prog_firehose_ddr.elf` 在 EDL 下「只稳定接受
LUN0」——错。真正原因是**调用形态**：**逐 LUN 分开调用**（每个 LUN 单独一次 `rawprogram`）时
LUN1-5 必被 NAK；而把全部 `rawprogram[0-5].xml` + `patch[0-5].xml` 在**一次**调用里传完
（先全部 rawprogram、再全部 patch）则 LUN0-5 全部写成。**与具体工具无关**：
- **qdl**（v2.3.9）合并调用：LUN0-5 全成功，78 patches、`partition 1 is now bootable`、退出码 0。
- **edl-ng** 合并调用（`flash-edl.sh` 现默认形态）：LUN0-5 全成功（含此前必 NAK 的 `xbl_a`/
  `xbl_config_a` boot LUN 与 LUN4 全套固件）——已用真机实测验证。

逐 LUN 分开调用的失败现象：对 LUN1-5 的首个 `program` 回
`NAK while waiting for Program raw mode ACK`，随后干等 ~30s 报 timeout；与 LUN 顺序、是否先刷
LUN0、是否重连、payload 大小都无关。**结论：一律用单次合并调用。** `flash-edl.sh` 已照此改造，
默认 `UFS_LUNS="0 1 2 3 4 5"`（只更新 OS、保留原引导固件时设 `UFS_LUNS=0`）。qdl 见下文
[用 qdl 全量刷写](#用-qdl-全量刷写lun05推荐用于换板bring-up)。

### 用 qdl 全量刷写（LUN0–5，推荐用于换板/bring-up）

`qdl`（mainline，本机 `/usr/bin/qdl` v2.3.9）能在 EDL 下写全部 LUN，是目前重写引导固件的可靠
手段。刷写集用 kas 自构建的**自洽子目录**
`build/tmp-glibc/deploy/images/<machine>/qcom-multimedia-image/`（含重命名后的
`efi.bin`/`system.img`/`dtb.bin` + `rawprogram[0-5].xml` + `patch[0-5].xml` + `prog_firehose_ddr.elf`）。

```bash
# 在上述 qcom-multimedia-image/ 目录内执行（相对文件名才能解析到镜像）
qdl -n -s ufs prog_firehose_ddr.elf \      # 先 -n dry-run 验证解析（不碰设备）
  rawprogram0.xml rawprogram1.xml rawprogram2.xml rawprogram3.xml rawprogram4.xml rawprogram5.xml \
  patch0.xml patch1.xml patch2.xml patch3.xml patch4.xml patch5.xml
# 去掉 -n 正式刷。-s ufs 必须；-i <dir> 可指定镜像搜索目录（不在 cwd 时）。
```

- **只显式列 `rawprogram[0-5].xml`**，绝不用 `rawprogram*.xml`（会误吃 `*_BLANK_GPT.xml` /
  `*_WIPE_PARTITIONS.xml`）。该子目录本身不含这些破坏性 XML，已确认。
- USB 受限时前缀 `sudo`。USB2 下 `efi`/`system` ~34–36MiB/s（system≈8.6GB 约 4–5 分钟），
  `dtb` ~32MiB/s，小固件分区（如 `tz`）吞吐更低属正常。
- qdl 刷完打印 `partition 1 is now bootable` 即结束，**不自动重启**，设备仍在 firehose。需要
  断电重上电（或另用 `edl-ng reset`）才正常启动。
- `flash-edl.sh` 现默认 edl-ng 单次合并调用刷全部 LUN（见下「用法」）；qdl 全量刷写为已验证的
  备选手动命令（见上）。

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
| `UFS_DIR` | 空 = 自动定位 `…/qcom-multimedia-image` | 显式指定 kas 自构建 UFS 镜像目录 |
| `UFS_LUNS` | `0 1 2 3 4 5` | 要刷的 UFS LUN 列表，单次合并调用一并写入；只想更新 OS（不重写引导固件）设 `UFS_LUNS=0` |
| `MAXPAYLOAD` | `1048576` | Firehose 单包字节数；**USB2 下加大无提速**（链路瓶颈），仅为兼容个别 loader 保留 |
| `FW_URL` | Radxa `dragon-q6a_flat_build_251013.zip`（**LE/QCLINUX**）URL | spinor 引导固件包下载地址；**必须是 LE 套件，勿用 wp_*** |
| `FW_DIR` | `scripts/firmware/` | 固件包下载/解压目录（gitignore） |
| `EDL_NG` | 空 | 显式指定 edl-ng 可执行文件，绕过自动定位 |
| `EDL_NG_URL` | Radxa `edl-ng-dist.zip` URL | edl-ng 自动下载地址 |

UFS 镜像目录、loader、spinor 目录均自动定位，无需手填路径。

**edl-ng 定位顺序**：`EDL_NG` 显式覆盖 → `scripts/edl-ng/`（已下载）→ PATH（如
`/usr/bin/edl-ng`）→ 自动下载到 `scripts/edl-ng/`。即系统已装则直接用，未装则自动拉取，
均不依赖工程外路径。

## edl-ng 命令对照

```
# 单次合并调用：一次传全部 rawprogram + patch（先全部 rawprogram，再全部 patch），
# 对齐 qdl 成功形态。--memory 枚举为大写：NAND|NVME|SDCC|SPINOR|UFS
edl-ng --loader prog_firehose_ddr.elf --memory UFS rawprogram \
  rawprogram0.xml rawprogram1.xml rawprogram2.xml rawprogram3.xml rawprogram4.xml rawprogram5.xml \
  patch0.xml patch1.xml patch2.xml patch3.xml patch4.xml patch5.xml
# 只刷 OS：edl-ng … rawprogram rawprogram0.xml patch0.xml
# 复位：normal 启动 / 回 EDL / 关机
edl-ng reset                  # = --mode reset（正常重启）
edl-ng --loader … reset --mode edl    # 重启回 EDL（清理卡住的 firehose 会话很有用）
```

> 脚本现把列表内所有 LUN 的 `rawprogram<N>.xml` + `patch<N>.xml` 在**一次** `rawprogram` 调用里
> 传完（先全部 rawprogram、再全部 patch），对齐实测成功的 qdl 形态；不再逐 LUN 分开调用。
> **只显式列 `rawprogram[0-9].xml`/`patch[0-9].xml`**，绝不用 `rawprogram*.xml`（会误吃破坏性的
> `*_BLANK_GPT.xml` / `*_WIPE_PARTITIONS.xml`）。UFS provisioning（`provision_*.xml`）有风险，未纳入。

## 排错（实测踩坑记录）

- **`NAK while waiting for Program raw mode ACK` → 30s 后 `operation has timed out`**：
  此现象只出现在 **逐 LUN 分开调用** LUN1-5 时；改用 **单次合并调用**（edl-ng 或 qdl 均可）即
  LUN0-5 全部写成——已真机实测验证。脚本已默认合并调用，正常不再出现此 NAK。若仍遇到，确认未
  退化成逐 LUN 调用；只想刷 OS 可设 `UFS_LUNS=0`。LUN0 上若出现 NAK 则多半是 firehose 会话卡死
  ——先 `edl-ng --loader … reset --mode edl` 清理再重试。
  注意：之前误判的「edl-ng 300s 命令超时」实为 `LUN0 写入 271s + NAK 后干等 30s ≈ 301s` 的巧合，
  并不存在硬性 300s 上限（LUN0 单独写 271s 可成功）。
- **写入恒为 ~34MiB/s**：设备多半枚举在 USB2（`cat /sys/bus/usb/devices/<d>/speed` = 480）。
  换 USB3 口/线可大幅提速；`MAXPAYLOAD` 调大在 USB2 下无效。
- **`未定位到 UFS 镜像目录`**：先 `kas build` 产出 `…/qcom-multimedia-image/`，或用 `UFS_DIR=` 指定。
- **中途切勿 kill `ufs`**：LUN0 的 `system.img` 写到一半被打断会损坏 OS 分区；要么等 LUN0 写完，
  要么之后重刷一次 LUN0。

## 相关
- [build-and-dev-workflow](build-and-dev-workflow.md) — 先 build 出 deploy/images
- [machine-qcs6490-radxa-dragon-q6a](../components/machine-qcs6490-radxa-dragon-q6a.md)
