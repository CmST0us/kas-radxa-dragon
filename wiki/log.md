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
