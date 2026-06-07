## 1. 搭建 meta 层骨架（自包含）

- [x] 1.1 在本仓库同级新建目录 `../meta-mipi-panel`，建立 `conf/`、`recipes-kernel/meizu-e3-panel/files/` 结构
- [x] 1.2 从 flange `meizu-e3-panel` 包拷入三套驱动源到 `files/`：`panel_meizu_e3/`（`.c` + `Makefile`）、`sec_ts/`（全部 `.c/.h` + 固件 `s6d6ft0_*.i` + `Makefile` + `Kconfig`）、`sgm37604a/`（`.c` + `Makefile`），拷贝时剔除构建产物（`*.o/*.ko/*.cmd/*.mod*` 等）
- [x] 1.3 从 flange 拷入 `device-tree/qcom-qcs6490-radxa-dragon-q6a-meizu-e3-panel.dtso` 到 `files/`（只拷 Q6A 这一份）
- [x] 1.4 写 `conf/layer.conf`：`BBFILE_COLLECTIONS = meizu-e3-panel`、`LAYERDEPENDS = radxa-dragon`、`LAYERSERIES_COMPAT = scarthgap`
- [x] 1.5 在 `conf/layer.conf` 末尾加三项普通变量接线（machine override 收口到 `qcs6490-radxa-dragon-q6a`）：`KERNEL_TECH_DTBO_PROVIDERS:append`、`IMAGE_INSTALL:append`、`KERNEL_MODULE_AUTOLOAD:append`。第四项 `KERNEL_TECH_DTBOS` 是 varflag，ConfHandler 不支持其 `:append`，改由 bbappend 实现（见 4.1 结论）
- [x] 1.6 准备 license 文件（`COPYING.MIT` 或复用既有 common-licenses），供配方 `LIC_FILES_CHKSUM` 引用

## 2. 编写单一配方

- [x] 2.1 新写根 `Makefile`（放 `files/`），用 `obj-m += panel_meizu_e3/ sec_ts/ sgm37604a/` 递归三子目录
- [x] 2.2 写 `meizu-e3-panel_1.0.bb`：`inherit module deploy`，`SRC_URI` 用 `file://` 引全部源与 `.dtso`，`S` 指向解包目录
- [x] 2.3 在配方 `do_compile` 中追加：`cpp` 预处理 + `dtc -@ -I dts -O dtb` 把 `.dtso` 编成 `meizu-e3-panel.dtbo`（`DEPENDS += dtc-native`）
- [x] 2.4 实现 `do_deploy`：把 `meizu-e3-panel.dtbo` 装到 `${DEPLOYDIR}/tech_dtbs/`；`addtask do_deploy after do_install`
- [x] 2.5 处理 OOT Makefile 的 `KSRC`（决策 4）：先按默认构建，必要时加 `EXTRA_OEMAKE += "KSRC=${STAGING_KERNEL_DIR}"`

## 3. kas 片段

- [x] 3.1 写 `meizu-e3-panel.yml`：`header.version` 与主配置一致，`repos` 仅加 `meta-mipi-panel`（`path: ../meta-mipi-panel`），不写 `local_conf_header`
- [x] 3.2 `kas dump kas-radxa-q6a.yml:meizu-e3-panel.yml` 确认 layer 被纳入、无解析错误

## 4. 验证（决策 1 + 风险项）

- [x] 4.1 决策 1 实测【已完成，结论：A 证伪 → 用 fallback】：`KERNEL_TECH_DTBOS[<machine>]:append` 在 ConfHandler 下解析失败（unparsed line）。改用 `linux-qcom-mergedtb.bbappend` 的 anonymous python 读机器配置已设值后增广。`bitbake -e linux-qcom-mergedtb` 确认 `KERNEL_TECH_DTBOS[qcs6490-radxa-dragon-q6a] = "qcm6490-graphics.dtbo qcm6490-video.dtbo meizu-e3-panel.dtbo"`；`KERNEL_TECH_DTBO_PROVIDERS` 含 `meizu-e3-panel`；layer 与配方均无解析错误，bbappend 正确匹配 mergedtb（非 dangling）
- [x] 4.2 【已完成】`bitbake meizu-e3-panel` 成功：三块 `.ko`（panel_meizu_e3/sec_ts/sgm37604a）编出，拆成 `kernel-module-{panel-meizu-e3,sec-ts,sgm37604a}` 包；`meizu-e3-panel.dtbo` 生成并 deploy 到 `deploy/images/.../tech_dtbs/`。仅 2 条预存无关 WARNING（gstreamer dangling、内核 src buildpaths）
- [x] 4.3 【已完成】host `fdtoverlay -v` 复刻 mergedtb 顺序（base→graphics→video→meizu）零报错，证明 base dtb 已导出所需 label（`&mdss_dsi/&i2c13/&tlmm/&vreg_*/&mdss_dsi0_out`）；合并树含 `panel@0`(meizu,e3-panel)、`touchscreen@48`(sec,sec_ts)、`backlight@36`(sgmicro,sgm37604a)，label 解析正确。真实 `combined-dtb.dtb` 将在 4.5 全量构建时由 mergedtb 产出
- [x] 4.4 【已完成，风险坐实并修复】真机 dmesg 证实 i2c13(a94000.i2c) `qcom,load-firmware` 找不到 `/lib/firmware/qupv3fw.elf`（-2）→ 总线 deferred → 背光/触摸/面板全 deferred → 屏黑。根因：upstream linux-firmware 无 qcs6490 版 qupv3fw.elf，它只在 `firmware-qcom-bootbins`(QCM6490_bootbinaries) 且仅 deploy 不进 rootfs。修复：新增配方 `qcom-qupv3fw-rootfs`（放**板层** `meta-radxa-dragon/recipes-bsp/qup-firmware/`，因属板级能力）从 `DEPLOY_DIR_IMAGE/qupv3fw.elf` 装进 rootfs `/lib/firmware/`，并经板层机器配置 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS` 进镜像（与 wifibt-firmware 同款）。运行时验证：喂固件+重绑 geni_i2c → i2c-13 上线 → sec_ts/sgm37604a probe → panel 绑定 → weston 驱动 1080x2160 → **屏点亮（用户确认）**。注：板层改动在本地副本，需切本地模式或 push+relock 才被构建采用
- [x] 4.5 【已完成】完整 `kas build kas-radxa-q6a.yml:meizu-e3-panel.yml` 成功，镜像含面板三模块 + qupv3fw + combined-dtb 面板节点（远端锁定 meta-radxa-dragon 7a0c513 / meta-mipi-panel scarthgap 2b3fab3）

## 5. 收尾与归档

- [x] 5.1 【已完成】真机刷入带固件镜像，开机即点屏（DSI-1 1080x2160@60，weston 出图）、触摸与背光可用，无需任何运行时干预（用户确认）
- [x] 5.2 【已完成】回填 wiki：新增 `wiki/components/mipi-panel-meizu-e3.md`；更新 `wiki/index.md`、`wiki/components/layers.md`（commit 升级 + qup-firmware + meta-mipi-panel）、`wiki/components/machine-qcs6490-radxa-dragon-q6a.md`（qupv3fw 板级固件）；`wiki/log.md` 追加一条 `change`
