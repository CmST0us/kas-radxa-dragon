# Log — kas-radxa-dragon

append-only 时间线。每条以 `## [YYYY-MM-DD] <type> | <title>` 开头。
速览最近 5 条：`grep "^## \[" wiki/log.md | tail -5`

---

## [2026-06-03] change | 从 repo 迁移到 kas，初始化仓库与 wiki
- 基于原 `repo` 项目（manifest `qcom-6.6.90-QLI.1.5-Ver.1.1_qim-product-sdk-2.0.1.xml`）
  生成 `kas-radxa-q6a.yml`：12 个 layer、machine `qcs6490-radxa-dragon-q6a`、distro `qcom-wayland`、
  target `qcom-multimedia-image`，`local_conf_header` 复刻原 local/auto/site.conf。
- 新增 `.gitignore`、`CLAUDE.md` 与本 `wiki/`。
- 影响页：全部（首建）。

## [2026-06-03] finding | AIC8800D80 WiFi/BT 驱动与固件现状
- 内核（radxa fork）已 in-tree 编译 aic8800 USB 驱动与 btusb（`qcom_defconfig` 中
  `CONFIG_AIC8800_WLAN_SUPPORT=m` / `CONFIG_AIC_LOADFW_SUPPORT=m` / `CONFIG_BT_AIC_BTUSB=m`），
  随 `kernel-modules` 进镜像。
- 但固件配方 `wifibt-firmware.bb` 原为孤立配方，未被任何 machine/image 引用 →
  `/lib/firmware/aic8800D80/` 默认为空，驱动可加载但芯片不工作。
- 影响页：components/driver-wifi-bt-aic8800d80.md, components/machine-qcs6490-radxa-dragon-q6a.md

## [2026-06-03] change | meta-radxa-dragon 切本地开发模式 + 装入 aic8800 固件
- `kas-radxa-q6a.yml` 中 `meta-radxa-dragon` 改为 `path: ../meta-radxa-dragon`（无 url，本地副本，
  改动即时生效），远端 url/branch/commit 留注释待回切。
- 本地 layer 的 `conf/machine/qcs6490-radxa-dragon-q6a.conf` 增加
  `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += " wifibt-firmware-aic8800d80-usb"`（commit `b82b968`，未 push）。
- 影响页：topics/versioning.md, topics/build-and-dev-workflow.md,
  components/layers.md, components/machine-qcs6490-radxa-dragon-q6a.md, components/driver-wifi-bt-aic8800d80.md

## [2026-06-03] change | meta-radxa-dragon 回切远端并锁定 scarthgap 最新 commit
- `kas-radxa-q6a.yml` 中 `meta-radxa-dragon` 由本地模式（`path: ../meta-radxa-dragon`）
  回切远端：启用 `url` + `branch: scarthgap` + `path: layers/meta-radxa-dragon`，
  `commit` 由旧的 `c898e25` 更新为 scarthgap 分支最新 `bf47b24`
  （`git ls-remote https://github.com/CmST0us/meta-radxa-dragon.git scarthgap`）。
- 影响页：components/layers.md, topics/versioning.md, CLAUDE.md（第五节状态备忘）。
- 相关文件：kas-radxa-q6a.yml

## [2026-06-04] change | 新增 GitHub Actions 构建工作流
- 新增 `.github/workflows/build.yml`：手动触发（workflow_dispatch，target 可选
  multimedia/console/minimal），ubuntu-24.04 runner，timeout 350min；先清磁盘再装
  Yocto host 依赖 + locale + kas，`kas dump` 健康检查后 `kas build --target`，
  上传 deploy/images 为 artifact。依赖 yml 中 `rm_work` 控制峰值磁盘。
- 背景：本地/容器环境磁盘仅 ~38GB，全量镜像构建在编译内核时 ENOSPC 失败，改用 CI 构建。
- 影响页：topics/build-and-dev-workflow.md（新增 CI 章节）, index.md
- 相关文件：.github/workflows/build.yml

## [2026-06-04] change | CI 修复 Ubuntu 24.04 user namespace 限制
- 首次 CI 运行报 "User namespaces are not usable by BitBake, possibly due to AppArmor"。
  Ubuntu 24.04 (noble) 默认用 AppArmor 限制非特权 user namespace，bitbake 需要它。
- 在 build.yml 加一步 `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`
  （checkout 之后、装依赖之前）。
- 影响页：topics/build-and-dev-workflow.md（CI 章节）
- 相关文件：.github/workflows/build.yml

## [2026-06-04] decision | 维持 QLI.1.5-Ver.1.1 基线，不 bump 到 scarthgap 尖端
- 曾检查发现 11 个远端 layer 中 10 个落后于其 scarthgap HEAD，并试 bump，但已**撤回**。
- 决定继续锁定 QLI.1.5-Ver.1.1 对应的 commit：Qualcomm BSP 与 meta-radxa-dragon 内核
  (kernel.qclinux.1.0.r1-rel) 都对齐该发布点，尖端 scarthgap 兼容性无保障。
- 影响页：topics/versioning.md

## [2026-06-04] change | 修复 gflags do_unpack（上游分支 master→main 改名）
- 根因：gflags(meta-oe scarthgap) 写死 `branch=master`，但 github 上游已将默认分支改名为 `main`，
  全新检出的镜像只有 main、无 master，unpack 的 `git branch --contains <rev> --list master` 返空。
  确认 SRCREV `e171aa2d` 是 main 的祖先。
- 修复：在 meta-radxa-dragon 加 bbappend
  `dynamic-layers/openembedded-layer/recipes-support/gflags/gflags_2.2.2.bbappend`，
  将 SRC_URI 改为 `branch=main`（SRCREV 不变）。**不复用旧 downloads**。
- 影响页：topics/build-and-dev-workflow.md, components/layers.md

## [2026-06-04] change | 新增 edl-ng 刷写脚本 scripts/flash-edl.sh
- 参考 flange `builder/flash.py:QualcommFlashStrategy`，写 EDL(9008) 刷写脚本。
- 子命令 detect/ufs/spinor/all/reset；系统盘走 QLI 分区刷写
  `edl-ng --loader prog_firehose_ddr.elf --memory UFS rawprogram <rawprogram*.xml> <patch*.xml>`，
  非 flange 的整盘 write-sector（Yocto 产出分区镜像+rawprogram，非单个 raw.img）。
- 设备探测读 /sys（VID:PID 05c6:9008），不抢 USB 会话。
- 影响页：topics/flashing.md（新增）, index.md

## [2026-06-04] decision | 路径规则：禁止工程外/本机路径引用
- CLAUDE.md 新增「一·五、路径规则（硬性）」：禁止 `/home/<user>/...` 等本机绝对路径与
  工程目录外引用；外部资源须下载进工程内（scripts/firmware/、downloads/）再用；唯一例外是
  本地开发的相对路径 `../meta-radxa-dragon`。
- 据此清理 CLAUDE.md/wiki/yml 中所有 `/home/eki/...`、旧 downloads 复用示例、本机 flat_build 路径。
- 影响页：（CLAUDE.md）, overview.md, topics/build-and-dev-workflow.md, components/driver-wifi-bt-aic8800d80.md

## [2026-06-04] change | flash 脚本改用 URL 下载固件包（去本机路径）
- flash-edl.sh 去掉本机 FLAT_BUILD 路径，改为从
  `dl.radxa.com/.../dragon-q6a_flat_build_wp_260120.zip` 下载并解压到 scripts/firmware/（gitignore），
  loader/spinor/ufs_hlos 在该目录内自动定位。新增 `fetch` 子命令。
- spinor 与 ufs 均默认用该固件包；UFS_DIR 可指向 kas 自构建 deploy/images/<machine>。
- 影响页：topics/flashing.md, .gitignore

## [2026-06-04] change | meta-radxa-dragon 回切远端，锁定 commit bf47b24
- 编译验证通过后，把 `kas-radxa-q6a.yml` 中 `meta-radxa-dragon` 从本地开发模式
  （`path: ../meta-radxa-dragon`）切回远端：`url=github.com/CmST0us/meta-radxa-dragon.git`、
  `branch=scarthgap`、`commit=bf47b24bdb3f30b20c5152fe46638aef6236d891`、`path=layers/meta-radxa-dragon`。
- 确认 `bf47b24` 即远端 scarthgap HEAD，已含本地开发期两笔提交：`b82b968`（装 AIC8800D80 固件）、
  `bf47b24`（gflags master→main）；本地无领先远端的提交，回切后构建不缺内容。
- `kas dump` 校验解析正常。
- 影响页：CLAUDE.md（第五节）, topics/versioning.md, topics/build-and-dev-workflow.md, components/layers.md

## [2026-06-04] change | flash 脚本 edl-ng 定位修正（去死路径 tools/）
- 原脚本指向不存在的 `tools/linux/edl-ng/edl-ng`。改为定位顺序：EDL_NG 覆盖 →
  scripts/edl-ng/（已下载）→ PATH（本机 /usr/bin/edl-ng 即命中）→ 自动下载到 scripts/edl-ng/。
- 与固件包一致：edl-ng 也按需下载进工程内，不依赖工程外路径。
- 影响页：topics/flashing.md, .gitignore

## [2026-06-05] finding | flash-edl 实刷调通：UFS 默认只刷 LUN0，逐 LUN 调用
- 设备进 EDL（9008，QCS_KODIAK）实刷验证，修好 `scripts/flash-edl.sh`：
  · UFS 镜像目录改为自动定位 `…/qcom-multimedia-image/`（自洽集，deploy 根目录缺重命名镜像）；
  · `--memory` 用大写枚举（SPINOR/UFS）；loader 优先用镜像目录内同版本。
- 关键实测结论（推翻多个初判）：
  · 本板 loader 在 EDL 下**只稳定接受 LUN0**（efi+system=OS）；LUN1/2=UFS boot LUN(xbl_a/b)、
    LUN3-5=固件，program 一律被 NAK，与顺序/重连/payload 无关。
  · 并无「edl-ng 300s 命令超时」——那是 `LUN0 写 271s + NAK 干等 30s ≈301s` 的巧合。
  · 写入恒 ~34MiB/s 因设备枚举在 USB2(480Mbps)；加大 MAXPAYLOAD 无效，换 USB3 才提速。
- 脚本改为**逐 LUN 独立调用**，默认 `UFS_LUNS=0`（只刷 OS，LUN0 失败才致命，余者告警）；
  glob 限 `rawprogram[0-9].xml` 杜绝误吃 `*_BLANK_GPT/_WIPE_PARTITIONS`（破坏性）。
- LUN0（efi+system+GPT+patch0）已完整刷入成功；引导固件 LUN 保持设备原内容。
- 影响页：topics/flashing.md（重写目标表/LUN 布局/排错/环境变量），scripts/flash-edl.sh

## [2026-06-06] finding | qdl 全量刷写 LUN0–5 成功：推翻「LUN1-5 不可写」结论
- 用官方 **qdl v2.3.9**（本机 /usr/bin/qdl）刷 kas 自构建固件，设备已在 EDL（05c6:9008）。
- 刷写集：`build/tmp-glibc/deploy/images/qcs6490-radxa-dragon-q6a/qcom-multimedia-image/`
  （自洽子目录：efi.bin/system.img/dtb.bin + rawprogram[0-5].xml + patch[0-5].xml + prog_firehose_ddr.elf）。
- 命令（在该目录内执行）：先 `qdl -n -s ufs prog_firehose_ddr.elf rawprogram0..5.xml patch0..5.xml`
  dry-run 验证，再去掉 -n 正式刷。
- **关键结论**：**LUN0–5 全部一次性写成功**，含 edl-ng 必 NAK 的 `xbl_a`/`xbl_config_a`(boot LUN)
  与 LUN4 全套固件(aop/dtb/uefi/tz/hyp/devcfg/…)；78 patches、`partition 1 is now bootable`、
  退出码 0、全程无 NAK。→ 先前「本板 loader 在 EDL 下只接受 LUN0」实为 **edl-ng 工具侧问题，
  非设备/loader 硬限制**（同一 prog_firehose_ddr.elf，换 qdl 即全过）。
- 速度（USB2）：efi 34952kB/s、system 35884kB/s(≈8.6GB,~4-5min)、dtb 32768kB/s、tz 4076kB/s。
- qdl 刷完不自动重启，设备仍在 firehose；需断电重上电或 edl-ng reset 才正常启动。
- 影响页：topics/flashing.md（LUN 布局表 edl-ng/qdl 双列、新增「用 qdl 全量刷写」、改标题/排错）

## [2026-06-06] change | flash-edl.sh edl-ng 改单次合并调用、默认刷全 LUN
- 受 qdl 全量刷写成功（见上条 finding）启发：qdl 是「一次传全部 rawprogram+patch」成功的，
  怀疑 edl-ng 此前 LUN1-5 NAK 系「逐 LUN 分开调用」所致。
- 改 `scripts/flash-edl.sh`：
  · `flash_rawprogram` 由逐 LUN 循环调用改为**单次合并调用**——收集列表内所有
    rawprogram<N>.xml + patch<N>.xml（先全部 raw 再全部 patch），一次 `edl-ng … rawprogram` 传完；
  · 默认 `UFS_LUNS` 由 `0` 改为 `0 1 2 3 4 5`（连引导固件一起刷）；只更新 OS 时设 UFS_LUNS=0；
  · 仍只显式取 rawprogram[N]/patch[N]，杜绝误吃 *_BLANK_GPT/_WIPE_PARTITIONS。
- ⚠️ 用户选择「还是用 edl-ng」（不切 qdl）。**edl-ng 合并调用能否真写成 LUN1-5 尚待实测**；
  若仍 NAK 则退回 UFS_LUNS=0 或改用已验证的 qdl。bash -n 通过、空 patches 数组展开安全。
- 影响页：topics/flashing.md（edl-ng 段/命令对照/环境变量表/排错），scripts/flash-edl.sh

## [2026-06-06] finding | 实测验证：edl-ng 合并调用同样写成 LUN0-5，根因=调用形态
- 用改后的 `scripts/flash-edl.sh`（edl-ng 单次合并调用、默认 UFS_LUNS=0 1 2 3 4 5）真机烧录，
  **LUN0-5 全部成功**（含此前必 NAK 的 xbl_a/xbl_config_a 等引导固件）。上条假设证实。
- **最终根因**：本板「EDL 下只接受 LUN0」是长期误判；真正原因是**调用形态**——逐 LUN 分开调用
  会让 LUN1-5 NAK，单次合并调用（一次传全部 rawprogram+patch）则 LUN0-5 全写成。**与工具无关**
  （edl-ng、qdl 合并调用均验证通过）。
- 已据此把 wiki 的「待验证」改为已验证，并对齐脚本注释。
- 影响页：topics/flashing.md（LUN 表改「逐LUN/合并」两列、根因段、intro 结论、排错），scripts/flash-edl.sh

## [2026-06-06] finding | 首启内核在 console 前静默挂死复位；加 earlycon 调试 cmdline 取证
- 现象：qdl 全量 LUN0–5 刷写后上电，UEFI 正常、`DetectLinuxKernelVersion` 成功、`Exit EBS UEFI End`
  后**零内核输出即热复位**（PSHOLD warm reset 计数 3→2→1），SBL1 见 dload cookie → `boot_dload_entry`
  → 落入 dload/EDL（USB PID 900e）等主机，表现为“卡住”。
- 排查（systematic-debugging）：
  · UEFI 阶段全程正常 ⇒ 非刷写未上/非引导固件损坏；故障在**内核早期、串口 console 起来之前**。
  · 证伪假设#1「dtb 错配」：dtb_a 在 LUN4，曾疑只刷 LUN0 留旧 dtb；但用户为 **qdl 全量 LUN0–5**，
    dtb/el2-dtb/tz/hyp 均同源 → 该假设不成立。
  · 核实：UKI(`linux-qcom-uki.bb`) 的 ukify **不含 `--dtb`**（DTB 由 UEFI 从 dtb_a 分区加载，不进 UKI）；
    `root=/dev/disk/by-partlabel/system`；UKI 含 initramfs(`initramfs-qcom-image`)；
    `qcom-multimedia-image` 是 **host** 镜像，Linux 跑在 **Gunyah EL2** 之上的 primary VM。
  · 当前 cmdline 有 `console=ttyMSM0` 但**无 `earlycon`**（`DEBUG_BUILD=0`）→ console probe 前的死法静默。
  · 用户补充：此板**之前用自定义镜像起过**，且“估计 UFS provisioning 也改过”（工作区 `scripts/provision/`
    有两套不同几何 provision_1_2/1_3）。但本板 `Boot Interface: SPI`、UEFI 已成功读 LUN0 内核，故
    provisioning 几何**非**本次 console 前挂死的元凶；性质偏“**回归**”（kas 构建内核 vs 旧能起镜像）。
  · 现存怀疑（待 earlycon 定位）：新 HLOS(内核/dtb/el2-dtb/UFS LUN4 tz/hyp) ↔ 出厂 **SPI 引导固件**
    （未刷 spinor，banner 仍 `BOOT.MXF...Jan2026`）在 Gunyah EL2 split 上不自洽。
- 动作：`kas-radxa-q6a.yml` 加临时 `local_conf_header: debug-bringup`，仅追加内核 cmdline
  （`earlycon keep_bootcon ignore_loglevel debug initcall_debug loglevel=8 printk.devkmsg=on
  no_console_suspend panic=0`），不动内核二进制/不翻 DEBUG_BUILD（保失败内核原样、只提升可见性）。
  重打 UKI、只刷 LUN0 后抓 `Exit EBS` 之后串口日志定位。**定位后须删除本段。**
- 影响页/文件：kas-radxa-q6a.yml（新增 debug-bringup）。**真因定位后**再回填 topics/flashing.md
  （“只刷 LUN0 vs 全量”“SPI/spinor 与 HLOS 固件需同源”）与 machine 页。
