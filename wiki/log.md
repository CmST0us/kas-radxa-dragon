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

## [2026-06-06] change | bring-up 期间关闭 rm_work 以加速增量编译
- `kas-radxa-q6a.yml` 的 `qcom-bsp` 段把 `INHERIT += "rm_work"` 注释掉（原继承自 QCOM auto.conf 基线）。
  rm_work 每个 recipe 完成后删 WORKDIR，省盘但增量慢（内核尤甚：WORKDIR 没了 → 每次从头 make）。
- 关掉**不触发全量重建**（rm_work 不参与其它任务签名，sstate 仍有效）；代价是 `work/` 涨到数十 GB。
- 折中：新增全注释占位段 `rm-work-dev`（`INHERIT += "rm_work"` + `RM_WORK_EXCLUDE += "linux-qcom-custom
  linux-qcom-uki qcom-multimedia-image"`）——磁盘紧张时启用，保留 rm_work 仅排除迭代中的 recipe。
- 注意：仅改 cmdline 时内核不重编（sstate 还原），耗时主要在 image do_image 重组 system.img(8.6GB)，
  与 rm_work 无关；rm_work 关闭主要利好「改内核源码/config」的循环。生产/CI 想省盘应改回开启。
- 影响页/文件：kas-radxa-q6a.yml（qcom-bsp 段、新增 rm-work-dev 占位段）。

## [2026-06-06] ingest | 整理 Qualcomm Linux 官方文档要点 → wiki/qualcomm-linux.html
- 深入抓取 Qualcomm Linux 两大官方文档 Build Guide（80-70020-254）+ Yocto Guide（80-70029-27/
  80-70022-27/80-80021-27/80-70018-27）的**全部子页面**，并与 `qualcomm-linux/*` GitHub 源码交叉核实，
  产出单页 `wiki/qualcomm-linux.html`（自带 TOC/样式）。
- 覆盖：版本基线/BSP 变体(QCOM_SELECTED_BSP custom/base)、metadata layers 依赖栈、meta-qcom-hwe 的
  machine 三层 conf 链(qcom-base.inc→qcom-qcs6490.inc→板conf，SOC_FAMILY=qcm6490)、双内核与固件、
  meta-qcom-distro/镜像、构建路线(manifest 表/源码=kas 等价/docker)、用户定制→kas 映射、刷写(firehose
  三件套/进 EDL/LUN 表)、启动链/systemd-boot+UKI/secure boot、分区·persist、OTA(capsule+ostree)、
  init/Gunyah VM/SD 启动/efivar/docker、排错速查，末尾「对本项目映射」与来源 URL 清单。
- 两条使用须知写进文档：①取正文用 `/doc/<docID>/topic/<slug>.html`（`/bundle/...` 为 JS 壳抓不到）；
  ②docs 默认展示较新版本(部分已 QLI 2.0/内核6.18)，须以本仓库 QLI.1.5 为准。
- 记下一处命名歧义：官方「自定义 machine」文档称通用层为 `qcom-armv8a.conf`(upstream meta-qcom 老路径)，
  而 QLI 产品线 meta-qcom-hwe 实际源码用 `qcom-base.inc`；稳定指令是板conf `require qcom-qcs6490.inc`。
- 影响页：index.md（新增「外部参考资料」入口），wiki/qualcomm-linux.html（新建）。

## [2026-06-06] finding | 镜像为 OSTree/sota；earlycon 静默实因 sota cmdline 丢 console=
- 刷入带 earlycon 的新 efi 后**仍零内核输出、热复位入 dload**。核验构建产物（md5 一致、刷的是最新）：
  UKI 的 `.cmdline` = `root=LABEL=otaroot rootfstype=ext4 … <earlycon 等 KERNEL_CMDLINE_EXTRA> …
  ostree=/ostree/boot.1/poky/4c0eb985…/0` —— **本镜像是 OSTree/sota 启动**。
- 根本可见性问题（非“内核死得更早”）：
  · `linux-qcom-uki.bb` 仅在 **非 sota** 分支加 `console=`(来自 SERIAL_CONSOLES)；sota 路径**丢掉 console=**
    → 即便内核正常也无串口输出。上次实验因此“被污染”，不能解读为死在 earlycon 之前。
  · 之前用的是**裸 `earlycon`**，依赖 DT `/chosen/stdout-path` 绑定；改用显式地址更稳。
- 取证：从 dtb.bin(vfat,FAT16) 按 FDT 魔数 carve 出 .dtb 反编译 → `stdout-path="serial0:115200n8"`、
  `serial0=/soc@0/geniqup@9c0000/serial@994000` ⇒ **调试 UART = GENI，基址 0x00994000**。
- sota 来源：**Qualcomm 发行版基线默认**（`meta-qcom-distro/conf/distro/include/qcom-base.inc`:24
  `DISTRO_FEATURES:append=" … sota"`），非本仓库添加；故 OSTree 是 QLI 既定设计。
- 动作：`kas-radxa-q6a.yml` 的 `debug-bringup` 改为显式
  `console=ttyMSM0,115200n8 earlycon=qcom_geni,mmio32,0x00994000 …`（铁定出字）。
- ⚠ OSTree 强耦合：efi(UKI+ostree karg) 与 system.img(ostree repo/部署 checksum) 必须同构建；
  **「只刷 efi」快捷循环对 sota 镜像不安全**，调试期 efi+system 一起刷（整 LUN0）。
- 下一步：① 显式 console+earlycon 重试看真因；② 若仍黑屏 → 拉 dload ramdump 读内核 `__log_buf`
  （绕开串口可见性）。注意：原始“全量刷写也不启动”早于本次快捷循环，OSTree 错配非元凶、仅潜在叠加。
- 影响页/文件：kas-radxa-q6a.yml（debug-bringup 改显式）。真因定位后回填 flashing.md/machine 页/distro-images。

## [2026-06-06] finding | 真因=SPI NOR 引导固件版本不匹配；刷 251013 spinor 后成功启动
- **根因确认**：设备出厂 SPI NOR 引导固件为 `260120`（UEFI banner `BOOT.MXF...Jan 20 2026`），
  与 kas 构建的 HLOS（内核/dtb/el2-dtb/hyp，radxa kernel.qclinux.1.0.r1-rel）**不兼容** →
  内核在 EL2 之上进入后早期静默挂死、热复位入 dload。**换 SPI 引导固件为 `251013` 后系统正常启动。**
- 操作：设备在 EDL(9008)，用 edl-ng 刷本地 `dragon-q6a_flat_build_251013/flat_build/spinor/dragon-q6a/`：
  `edl-ng --loader prog_firehose_ddr.elf --memory SPINOR rawprogram rawprogram0.xml patch0.xml` → `edl-ng reset`。
  写入 cdt/XBL/XblRamdump/XBL_CONFIG/UEFI/AOP/TZ/DEVCFG/HYP/QUP/CPUCP/SHRM/ImageFv/GPT 全 100%，
  exit 0；缺失的 `fat12test.bin`(FATTEST) 被 edl-ng 自动跳过（非致命，**edl-ng 遇缺文件是跳过不中止**）。
- 教训/启示：
  · 之前几轮（dtb 错配 / OSTree console / earlycon 可见性）均为支线；真正变量是 **SPI 侧引导固件**——
    UFS 全量刷写只换 UFS LUN，SPI NOR 始终是出厂版，与新 HLOS 不配套。
  · **bring-up 换 HLOS 时，SPI 引导固件需与之配套**（同一 flat_build 套件的 spinor + ufs 才自洽）。
  · 串口可见性结论仍有效留存：sota/OSTree 镜像 cmdline 不含 console=（仅非 sota 加）；调试 UART
    GENI 基址 `0x00994000`（`earlycon=qcom_geni,mmio32,0x00994000`）。
- 已移除 `kas-radxa-q6a.yml` 的临时 `debug-bringup` 段（保留 rm-work-dev 占位）。
- 影响页/文件：kas-radxa-q6a.yml（删 debug-bringup）。**待回填**：topics/flashing.md（新增「SPI 引导固件与
  HLOS 需配套；spinor 刷写来源/版本」）、machine 页、distro-and-images（OSTree/console 备注）。

## [2026-06-06] finding | 订正根因：是 LE vs WP 两套 OS 固件，不是「新旧版本不匹配」；并修脚本默认刷 WP 的坑
- **逐文件比对** `dragon-q6a_flat_build_251013`(能启动) 与 `dragon-q6a_flat_build_wp_260120`(原厂,起不来)
  两套 spinor，铁证在 `contents.xml`：前者 `QCM6490.`**`LE`**`.1.0`/`hlos_type=LE`/`LE.QCLINUX.1.0.r1`；
  后者 `QCM6490.`**`WP`**`.1.0`/`hlos_type=WP`/`<windows_root_path>` —— **WP = Windows Platform**。
- 关键差异：HYP `hypvm.mbn`(1.5MB,Gunyah,Linux 主 VM) vs `hyp.mbn`(427KB,Windows hyp)；DEVCFG `devcfg.mbn`
  vs `devcfg_windows_hyp_rfcomm.mbn`；UEFI 独立 `uefi.elf`(含 FDT 机制 `SecFdtInitRootHandle`/`fdt_header`,
  发设备树) vs `PILFV.Fv`(WoA PI 卷,发 ACPI+SMBIOS)；WP 专有分区 VarStore/SMBIOS/PILFv/TZAPPS/DPP/SSD；
  XBL 变体 `SocKodiakLAA`/`KODIAKLA` vs `SocKodiakWP`/`KODIAKWP`；TZ.XF 5.29(KODIAK) vs 5.11(LAHAINA)。
- 机理（解释「earlycon 都零输出 + 热复位入 dload」）：本仓库 HLOS 是 QCLINUX/LE，UKI 不内嵌 dtb，
  设备树靠 UEFI 提供且跑 Gunyah 主 VM。WP 固件下 ① UEFI 不发 DT → 内核找不到 GENI UART(0x00994000)→
  连 earlycon 都无字；② WP hyp 给 Windows guest 配 EL2 → Linux 期望的 Gunyah 主 VM 不在 → EL2 异常热复位。
- **订正前条 finding**：把它表述为「260120(新) vs 251013(旧) 版本不匹配」**不准确**——与版本新旧无关
  （WP boot 版本 `00549` 反比 LE 的 `00364` 更新），实为 **目标 OS（Linux/LE vs Windows/WP）整套不同**。
  「UFS 全量刷不碰 SPI NOR、故 SPI 的 Windows 引导栈残留」这一结论仍成立。
- **修复制度性坑**：`scripts/flash-edl.sh` 的 `FW_URL` 原默认 `dragon-q6a_flat_build_wp_260120.zip`(WP!)，
  即 `spinor`/`all` 默认会把 Windows 引导固件刷进 SPI → 必然起不来。已改默认为
  `dragon-q6a_flat_build_251013.zip`（LE，URL 经 HEAD 校验 200 且 Content-Length 与本地 zip 一致）；并在
  `cmd_spinor` 加安全网：固件目录含 `PILFV.Fv`/`devcfg_windows_hyp*`/`hyp.mbn` 等 WP 特征即拒刷并提示清缓存重取。
  注意：`scripts/firmware/` 现仍残留旧的 WP 解压物，需 `rm -rf scripts/firmware && scripts/flash-edl.sh fetch`
  才会按新 URL 取 LE 包（否则被安全网拦下）。
- 影响页/文件：scripts/flash-edl.sh（FW_URL 改 LE + cmd_spinor 拒刷 WP）、topics/flashing.md（新增「SPI
  引导固件必须 LE/不能 WP」一节 + 改固件来源/FW_URL）、components/machine-*.md（加引导固件配套备注）。

## [2026-06-06] finding | GPU/VPU/USB(adb+aic8800wifi) 全废，根因=设备跑的 DTB 与本 BSP 内核不匹配
- 现象（ssh root@设备实测）：① 无 `/dev/dri/card*`、无 renderD128，`gpu@3d00000`/`gmu` 驱动未绑定 → GPU 不工作；
  ② 无 `/dev/video*`，`qcom-venus aa00000.video-codec` probe 失败 → VPU 不工作；③ 仅 `lo`/`eth0`，无任何
  wlan，aic8800 USB 驱动未加载，`/sys/bus/usb/devices/` 为空（无 USB host 总线）→ aic8800 WiFi 不工作；
  ④ 设备侧 adbd 在跑、configfs 有 adb 功能、`/dev/usb-ffs/adb` 已挂，但 `/sys/class/udc/` 为空（无 UDC）→
  主机 `adb devices` 空、无法 adb shell。
- 取证：重启抓 boot.log（dmesg 环被 pulseaudio 反复段错误的 audit 刷掉，须重启后立刻快照）。关键报错：
  `qcom-venus ... Direct firmware load for qcom/vpu-2.0/venus.mbn failed -2`（盘上是 `vpu20_1v.mbn`）；
  `msm-mdss ae00000.display-subsystem: failed to acquire mdss reset` → -22；两个 dwc3 控制器
  `8c00000.usb`/`a600000.usb` 全程无 probe，手动 bind dwc3-qcom 返回 -ENODEV。
- 根因（铁证）：设备 DTB 与本 BSP 内核来自不同来源。设备 DTB 节点 compatible 为
  `qcom,snps-dwc3`（dwc3-qcom 只匹配 `qcom,dwc3` → 永不绑定）、venus 默认要 `venus.mbn`、DSP 固件路径
  `qcom/qcs6490/radxa/dragon-q6a/*.mbn`、USB 同时存在 `8c00000`+`a600000`。这些字符串在本 BSP 内核源码树
  （radxa/kernel rev `2e366d0`，即设备实际运行的内核）里**完全不存在**。反编译本次构建的
  `qcs6490-radxa-dragon-q6a.dtb` 与合并产物 `combined-dtb.dtb`：USB 为 `usb@8cf8800`/`a6f8800`
  `qcom,sc7280-dwc3`+`qcom,dwc3`（驱动能匹配）、GPU `qcom,adreno-635.0`+zap-shader(`a660_zap.mbn`)、
  DSP 路径 `qcom/qcs6490/*.mdt` —— 与设备 DTB 完全两棵树。
- 机理串联：内核是本次新构建（uname rev 匹配 2e366d0），但 DTB 仍是 `flat_build_251013`(LE) 引导固件里的
  stock DTB（见前条：UKI 不内嵌 dtb、设备树由 UEFI/引导固件提供；只刷 UFS LUN0 OS 不会更新 DTB）。
  新内核 + 旧/外来 DTB → dwc3 不绑定（连带 adb 无 UDC、aic8800 USB host 不通）、mdss reset 取不到、
  GPU/GMU/venus 全 probe 失败。
- 次要待办（修 DTB 后复测再定）：a) GPU 驱动模块——当前加载只含显示的 `msm_display.ko`，adreno GPU 在
  mainline `msm.ko`（`msm_default/msm.ko`）里，需确认正确 DTB 下用哪套；b) venus 固件名——combined-dtb 的
  venus 节点无 `firmware-name` 覆盖、默认 `venus.mbn`，盘上只有 `vpu20_1v.mbn`，可能仍需在 video dtbo 加
  `firmware-name` 或提供 `venus.mbn`；c) 还需实际构建/刷 `dtb-qcom-image`(combined-dtb) 到 dtb 来源，且
  确认 UEFI 取 dtb 的位置（分区 vs UEFI 内嵌）。
- 旁证（非本次目标，记录备查）：pulseaudio 每 ~3s 段错误刷 audit 日志；lpass `33c0000.pinctrl` 拿不到
  `core` 时钟连累音频 deferred；remoteproc adsp/cdsp `.mbn` 缺失；geni i2c/spi QUP 固件 -22；`usb_fw`
  分区(/dev/sdd3)未格式化、`var-usbfw.mount` 失败。
- 影响页/文件：components/machine-qcs6490-radxa-dragon-q6a.md（GPU/VPU/USB 与 DTB 来源），
  components/driver-wifi-bt-aic8800d80.md（aic8800 依赖 USB host，先决条件=正确 DTB），topics/flashing.md
  （DTB 来源/dtb-qcom-image 与引导固件 stock dtb 的关系）。诊断命令与 boot.log 取证法可回填上述页。

## [2026-06-06] finding | 定位 DTB 来源：UEFI 内嵌（非 dtb 分区）——分区里其实是正确的 BSP dtb 却被无视
- 背景：承接上条，需确认设备 DTB 来自 `dtb` 分区还是 UEFI 内嵌，以定修复落点。
- 取证（ssh + scp，已装公钥免密）：
  · 运行中内核拿到的 fdt：`/sys/firmware/fdt` = 138440B，md5 `78cba8ae…`；反编译为 USB `qcom,sc7280-dwc3`+
    `qcom,snps-dwc3`、gpu `qcom,adreno-635.0`(无 zap 绑定)、venus `qcom,sc7280-venus`、**无 qcom,msm-id/board-id**，
    且多一个 `model="QCS6490-Radxa-Dragon-Q6A"` 子节点。
  · `dtb_a` 分区(sde2，64MB FAT 镜像)：全区仅 1 处 FDT magic，提取出的 dtb = 238428B，md5 `e6492c8a…`，
    **与本次构建的 `combined-dtb.dtb` 字节完全一致**（USB `qcom,dwc3`、gpu+zap-shader `a660_zap.mbn`、
    有 `qcom,msm-id=<497/498/475/515 …>`、`qcom,board-id=<32,2/32,602>`、`qcom,gpu-model="Adreno643v1"`）。
  · `dtb_b`(sde20) 全 0；uefi_a(sde5)/imagefv(sde13) 内无 FDT magic、无 `snps-dwc3` 串。
  · 真凶：解压 SPI NOR `flat_build/spinor/dragon-q6a/uefi.elf` 偏移 315880 的 gzip 段(5.6MB)，内含
    `snps-dwc3`×2 + `QCS6490-Radxa-Dragon-Q6A`×1 —— 即运行中那棵 138KB dtb 的指纹。
- 结论：**设备 DTB 由预编译 UEFI（SPI NOR 的 `uefi.elf`，来自 `flat_build_251013`）gzip 内嵌提供，UEFI 完全
  不读 `dtb` 分区**。而 `dtb` 分区里恰恰是正确的 BSP combined-dtb（与构建产物一致），白白被无视。
- 成因：内核是用户自构建(radxa/kernel rev 2e366d0)，UEFI 却用 Radxa 预编译 251013 包，两者内嵌的设备树
  已分叉 → 新内核 + UEFI 旧内嵌 dtb = USB(`snps-dwc3`无驱动)/GPU/VPU/display 全失败。
- 修复方向（候选，待选型）：① 让 UEFI 改从 `dtb` 分区按 msm-id/board-id 择优加载（BSP dtb 已带这两属性，
  若 UEFI 支持分区加载则最干净）——需查这版 Radxa QCLINUX UEFI 的 dtb 加载策略/开关；② 换用内嵌正确 dtb
  或支持分区加载的更新 UEFI/boot 固件（注意 LE，勿 WP）；③ 重打 uefi.elf 内嵌 dtb（脆弱、可能涉签名，不推荐）。
  仅刷 `dtb` 分区/`dtb-qcom-image` 对本机无效（UEFI 不读它）。
- 影响页/文件：topics/flashing.md（新增「DTB 来源=UEFI 内嵌、dtb 分区被无视」一节）、
  components/machine-qcs6490-radxa-dragon-q6a.md（DTB 来源与 boot 固件配套）。

## [2026-06-06] finding | UEFI dtb 加载策略查清：内嵌发 DT、不读 dtb 分区；路径1 不可行，正解=systemd-boot `devicetree` 行
- 目标：确认这版 UEFI 是否会从 dtb 分区加载、路径1（让 UEFI 读分区）是否可行。
- UEFI 取证（解压 SPI NOR `uefi.elf` 的 gzip FV 段 + 设备 efivars/ESP）：
  · UEFI = Qualcomm Linux SPF 1.0 / KodiakLAA（QCS6490 LE，预编译）。FV 里只有 `DTBExtnProtocol` + `DtbBuffer`
    变量机制，**无任何 dtb 分区加载/分区 GUID 字符串**；运行 dtb 指纹(`snps-dwc3`×2 等)就在 FV 的 gzip 段里。
    → UEFI 把 base dtb 编死在 FV，经 DtbBuffer/EFI DT 表发出，**不读 dtb_a 分区**。
  · UEFI **提供 `EFI_DT_FIXUP_PROTOCOL`**（FV 有 `DtFixup` 事件注册）——外部 dtb 可被固件做内存等修正。
  · Secure Boot = **关闭**（`SecureBoot` efivar 值 0）。
- 启动链（设备 ESP 实查）：UEFI → **systemd-boot 255.17**(`/boot/EFI/BOOT/bootaa64.efi`) →
  **type-1 条目** `/boot/loader/entries/ostree-1.conf`（OSTree 管理，分立 `linux /ostree/.../vmlinuz` +
  `initrd …`，**非 UKI**）→ 内核。条目**无 `devicetree` 行** → sd-boot 透传固件内嵌 dtb 给内核 = 病根直接原因。
  注：`linux-qcom-uki.bb` 虽建 UKI 且 ukify 缺 `--dtb`，但 sota/ostree 路径走 type-1 条目、不经该 UKI。
- 结论：**路径1（让 UEFI 从 dtb 分区加载）不可行**——UEFI 是签名预编译 SPF blob，无对外开关、无法重编，
  dtb_a 永不被读。**订正**前述 wiki/log「DTB 由 UEFI 从 dtb_a 分区加载」为错误假设（该假设曾导致误判 dtb 非病因）。
- 正解（已验证可行、且在 BSP 内）：给 systemd-boot 的 type-1 条目加 `devicetree <BSP combined-dtb>` 行并把该
  dtb 部署到 ESP/ostree boot 目录。sd-boot 255.17 支持 `devicetree` + UEFI 有 `EFI_DT_FIXUP_PROTOCOL`，
  会加载 BSP dtb 并带固件修正安装，覆盖内嵌 dtb。BSP dtb 已含 USB `qcom,dwc3`/GPU zap/msm-id，覆盖后
  USB(adb+aic8800)/GPU/VPU/display 应一并恢复。可先在设备上手改条目热验证（reversible，注意单条目误改不启动需 EDL 兜底）。
- 影响页/文件：topics/flashing.md（DTB 来源=UEFI 内嵌、修法=sd-boot devicetree）、qualcomm-linux.html 与本 log
  line165 的「从 dtb_a 加载」需订正、components/machine-*.md（boot/dtb 机制）。集成落点：OSTree/bootloader 条目
  生成处（meta-updater/sota 或 KERNEL_DEVICETREE 部署 + 条目模板加 devicetree）。

## [2026-06-06] finding | 代码级坐实内核 dtb 加载逻辑：arm64 EFI stub 从 EFI 配置表取 dtb；多一条 `dtb=` 修复杠杆
- 源码(本机检出 kernel-source) `drivers/firmware/efi/libstub/fdt.c` `allocate_new_fdt_and_exit_boot`：
  · fdt.c:249-260 若 `CONFIG_EFI_ARMSTUB_DTB_LOADER` 且 secure boot 关 且 cmdline 含 `dtb=` → `efi_load_dtb()`
    从 ESP 文件加载（"Using DTB from command line"）；
  · 否则 fdt.c:266 `get_fdt()` → fdt.c:364 `get_efi_config_table(DEVICE_TREE_GUID)` 读 EFI 配置表里
    引导层/固件装入的 dtb（"Using DTB from configuration table"）；都无则空 dtb。
- 即 arm64+UEFI 下内核不自带/不指定 dtb，取自 EFI 配置表 —— 由引导层决定。现状：sd-boot 条目无
  `devicetree` 行、cmdline 无 `dtb=` → 配置表里是 UEFI 内嵌 stock dtb → 内核用错。内核行为本身正确。
- 设备内核配置已查证：`CONFIG_EFI_ARMSTUB_DTB_LOADER=y`、`CONFIG_EFI_GENERIC_STUB=y`，Secure Boot 关。
- 故有两条修复杠杆（均从 ESP 读正确 BSP dtb、均不碰 UEFI）：
  A) boot 条目加 `devicetree <dtb>`（sd-boot 255.17 装入配置表，UEFI 有 EFI_DT_FIXUP_PROTOCOL）；
  B) cmdline(options) 加 `dtb=<dtb>`（内核 stub 直接加载，优先级高于配置表；本机条件满足）。
- 集成落点：A/B 都需把 BSP combined-dtb 部署进 ESP/ostree boot 目录，并在 OSTree 启动条目生成处注入
  devicetree 行或 dtb= cmdline（meta-updater/sota bootloader 集成）。

## [2026-06-07] change | 落地路径 A（OSTREE_DEPLOY_DEVICETREE）修复 dtb：USB/GPU/VPU/display 全恢复
- 承接 2026-06-06 finding，实施 change `fix-dtb-via-ostree-devicetree`（openspec），分两步并真机验证通过。
- 修法：打开 `OSTREE_DEPLOY_DEVICETREE` 让 OSTree 在 systemd-boot type-1 条目写出 `devicetree` 行，
  指向构建出的 `combined-dtb.dtb`（含 graphics/video 叠加）覆盖 UEFI 内嵌旧 stock dtb。
- 落地改动（均在本地副本 meta-radxa-dragon；kas 切本地开发模式 `path: ../meta-radxa-dragon`）：
  · `conf/machine/qcs6490-radxa-dragon-q6a.conf`：`OSTREE_DEPLOY_DEVICETREE:forcevariable="1"` +
    `OSTREE_DEVICETREE:forcevariable="combined-dtb.dtb"`；
  · `recipes-kernel/images/linux-qcom-mergedtb.bb`：加 `inherit deploy` + `do_deploy`（投
    combined-dtb.dtb 到 DEPLOY_DIR_IMAGE）+ `addtask deploy after do_compile before do_build`；
  · 新建 `recipes-sota/ostree-kernel-initramfs/ostree-kernel-initramfs_%.bbappend`：
    `do_install[depends] += "linux-qcom-mergedtb:do_deploy"`。
- 实施中发现并修正的两个坑：① distro qcom-base.inc 硬 `=` 写死这三个变量、解析在 machine/local 之后，
  普通 `=` 会被盖回 → 必须 `:forcevariable`；② `OSTREE_DEVICETREE` 默认 `${KERNEL_DEVICETREE}` 在
  ostree-kernel-initramfs 配方里为空（KERNEL_DEVICETREE 是 :pn-linux-qcom-custom 限定）→ 必须显式设。
- 验证：构建层 `ostree-*.conf` 出现 `devicetree` 行、部署 devicetree=238428B（=combined）；真机 adb
  `/sys/firmware/fdt`=240545B、USB(dwc3)/GPU(kgsl Adreno643v1)/VPU(iris venus)/display(card0+HDMI) 全好。
  残留 `msm_dpu: no GPU device` 为 KGSL/DRM 架构分离的良性提示，与本改动无关。
- 影响 wiki 页：新增 topics/dtb-and-boot-devicetree.md（主页面）；更新 components/machine-*.md、index.md。
- 相关：openspec/changes/fix-dtb-via-ostree-devicetree/（proposal/design/specs/tasks）。
