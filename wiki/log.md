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
