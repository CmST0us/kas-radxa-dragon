# meizu-e3-panel

## Purpose

定义魅族 E3 39pin MIPI-DSI 屏（显示 + 触摸 + 背光）在 Radxa Dragon Q6A（QCS6490）上的固件适配能力：以独立、可选、可组合的 meta 层提供三块 OOT 驱动与设备树叠加，并复用现有 DTB 合并与部署管线进入固件。

## Requirements

### Requirement: 以独立可组合 kas 片段提供面板支持

系统 SHALL 通过独立的 kas 片段 `meizu-e3-panel.yml` 提供面板支持，使用户能以 `kas build kas-radxa-q6a.yml:meizu-e3-panel.yml` 组合出带屏固件；不组合该片段时，构建结果 MUST 与未引入本变更前的基线一致。

该片段 SHALL 只负责引入 `meta-mipi-panel` 这一个 layer，面板的全部接线（dtbo 登记、provider 登记、装包、模块自动加载）MUST 由该 layer 自身承载，而非写在 kas 片段的 `local_conf_header`。

#### Scenario: 组合片段构建出带屏固件

- **WHEN** 执行 `kas build kas-radxa-q6a.yml:meizu-e3-panel.yml`
- **THEN** 构建成功，且最终镜像包含面板三块驱动与合并了面板节点的设备树

#### Scenario: 不组合片段时基线不受影响

- **WHEN** 执行 `kas build kas-radxa-q6a.yml`（不带片段）
- **THEN** 构建产物与未引入本变更前一致，不含任何面板驱动或面板设备树节点

### Requirement: 自包含 meta 层，不跨工程引用

`meta-mipi-panel` 层 MUST 自包含：三块驱动源码（`panel_meizu_e3`、`sec_ts`、`sgm37604a`，含 `sec_ts` 的固件 `.i`）与设备树 `.dtso` MUST 拷入本 layer 的 `files/` 目录，配方以 `file://` 引用。配方 MUST NOT 通过绝对路径或跨工程相对路径引用本 layer 之外（如外部 flange 工程）的源码。

#### Scenario: 配方源码均在 layer 内

- **WHEN** 检视 `meizu-e3-panel_1.0.bb` 的 `SRC_URI` 及其 `file://` 来源
- **THEN** 所有源文件都位于 `meta-mipi-panel/recipes-kernel/meizu-e3-panel/files/` 之下，无任何工程外路径引用

### Requirement: 单一配方构建三块驱动并部署面板 dtbo

`meta-mipi-panel` 层 SHALL 提供单一配方 `meizu-e3-panel`，一次性产出面板的三块内核模块与一个设备树叠加：

- 三块 `.ko`（`panel_meizu_e3.ko`、`sec_ts.ko`、`sgm37604a.ko`）MUST 编译成功并装入镜像的内核模块目录；
- 设备树 `.dtso` MUST 经 `dtc` 编成 `meizu-e3-panel.dtbo`，并经 `do_deploy` 投放到 `DEPLOY_DIR_IMAGE/tech_dtbs/`，供 `linux-qcom-mergedtb` 取用。

#### Scenario: 三块内核模块编译并安装

- **WHEN** 构建 `meizu-e3-panel` 配方
- **THEN** `panel_meizu_e3.ko`、`sec_ts.ko`、`sgm37604a.ko` 均编出且被打入镜像的 `lib/modules/<ver>/` 下

#### Scenario: 面板 dtbo 部署到 tech_dtbs

- **WHEN** `meizu-e3-panel` 配方执行到 `do_deploy`
- **THEN** `DEPLOY_DIR_IMAGE/tech_dtbs/meizu-e3-panel.dtbo` 存在

### Requirement: 复用现有 DTB 合并管线把面板 dtbo 并入 combined-dtb

面板设备树 MUST 经现有 `linux-qcom-mergedtb` 管线，用 `fdtoverlay` 合并进 `combined-dtb.dtb`，再经现有 `OSTREE_DEPLOY_DEVICETREE` 机制进入固件；本变更 MUST NOT 新增独立的 dtb 合并或部署机制，也 MUST NOT 改动 `linux-qcom-mergedtb` 的配方源（dtbo 登记须用面板层自带的 bbappend 增广，而非编辑 `meta-radxa-dragon` 中该配方）。

为此，面板层 MUST 把 `meizu-e3-panel.dtbo` 追加进 `KERNEL_TECH_DTBOS[qcs6490-radxa-dragon-q6a]`，并把配方追加进 `KERNEL_TECH_DTBO_PROVIDERS`；追加 MUST 能盖过机器配置中对该变量的硬 `=` 赋值（解析顺序约束）。

#### Scenario: 面板节点出现在 combined-dtb

- **WHEN** 以组合片段构建后检视 `DEPLOY_DIR_IMAGE/combined-dtb.dtb`
- **THEN** 该 dtb 中存在面板相关节点（`panel@0` 含 `compatible = "meizu,e3-panel"`、`touchscreen@48`、`backlight@36`）

#### Scenario: 追加登记盖过机器配置硬赋值

- **WHEN** 以组合片段构建并查看最终 `KERNEL_TECH_DTBOS[qcs6490-radxa-dragon-q6a]`
- **THEN** 其值同时包含机器配置原有的 `qcm6490-graphics.dtbo`、`qcm6490-video.dtbo` 与本变更追加的 `meizu-e3-panel.dtbo`

### Requirement: 面板接线限定 Q6A 机器，且模块自动加载

面板层对镜像装包、模块自动加载、dtbo 与 provider 登记的全部追加 MUST 用 machine override 收口到 `qcs6490-radxa-dragon-q6a`，以免该 layer 被其他机器（如 `qcs9075-radxa-airbox-q900`）误包含时误装面板内容。三块模块 MUST 配置为自动加载（`KERNEL_MODULE_AUTOLOAD`），以保证开机点屏与触摸/背光可用。

#### Scenario: 模块开机自动加载

- **WHEN** 以组合片段构建的固件启动后检视已加载模块
- **THEN** `panel_meizu_e3`、`sec_ts`、`sgm37604a` 均已加载

#### Scenario: 非 Q6A 机器不误装面板

- **WHEN** 该 layer 在场但目标机器非 `qcs6490-radxa-dragon-q6a`
- **THEN** 该机器的镜像不追加面板驱动、面板 dtbo 与面板模块自动加载项

### Requirement: rootfs 须提供 i2c GENI SE 固件 qupv3fw.elf（板级能力）

面板的触摸(0x48)与背光(0x36)挂在 i2c13(a94000.i2c) 上，该 SE 未被 bootloader 预配为 I2C，`.dtso` 给 i2c13 声明了 `qcom,load-firmware`，内核 geni_i2c MUST 从 `/lib/firmware/qupv3fw.elf` 加载 SE 固件后总线方能上线。upstream linux-firmware 不含 qcs6490 版 qupv3fw.elf，故构建 MUST 把该固件（来自 `firmware-qcom-bootbins` 的 `QCM6490_bootbinaries`）装进 rootfs 的 `/lib/firmware/qupv3fw.elf`。

该固件是【板级】基础能力（任何声明 `qcom,load-firmware` 的 SE 都需要），故由板层 `meta-radxa-dragon` 的 `qcom-qupv3fw-rootfs` 配方提供、并经机器配置 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS` 随镜像进（与 wifibt-firmware 同性质），而非放在面板层 `meta-mipi-panel`。面板层只是该能力的消费者。

缺该固件时 i2c13 总线 deferred，背光/触摸/面板连锁 deferred，屏幕不亮。

#### Scenario: rootfs 含 qupv3fw.elf 且 i2c13 开机上线

- **WHEN** 以组合片段构建并刷机后启动
- **THEN** `/lib/firmware/qupv3fw.elf` 存在；dmesg 出现 `geni_i2c a94000.i2c: Firmware load for I2C protocol is Success`；`/sys/bus/i2c/devices/i2c-13` 及其上 `13-0036`(背光)、`13-0048`(触摸) 均出现

#### Scenario: 面板、触摸、背光开机即可用

- **WHEN** 刷入带面板特性的镜像并正常启动（无需任何运行时干预）
- **THEN** `panel-meizu-e3` 绑定到 `ae94000.dsi.0`，DSI-1 连接器以 `1080x2160@60` 使能，背光 `sgm37604a` 注册、屏幕点亮，触摸 input 设备注册
