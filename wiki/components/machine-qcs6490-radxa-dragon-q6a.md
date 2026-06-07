# Machine: qcs6490-radxa-dragon-q6a

_最后更新：2026-06-07_

Radxa Dragon Q6A 开发板的机器配置，定义在
`meta-radxa-dragon/conf/machine/qcs6490-radxa-dragon-q6a.conf`，SoC 为 Qualcomm **QCS6490**。

## 关键配置

- `require conf/machine/include/qcom-qcs6490.inc`（继承 meta-qcom-hwe 的 QCS6490 通用配置）
- `MACHINE_FEATURES = "usbhost usbgadget alsa wifi bluetooth"`
- 设备树：`qcom/qcs6490-radxa-dragon-q6a.dtb`（`pn-linux-qcom-custom`）
- DTBO 叠加：`qcm6490-graphics.dtbo`、`qcm6490-video.dtbo`
  （providers：`qcom-graphicsdevicetree`、`qcom-videodtb`）
- `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += " wifibt-firmware-aic8800d80-usb"`
  —— 本仓库新增，给 AIC8800D80 装固件，见 [driver 页](driver-wifi-bt-aic8800d80.md)。

继承自 `qcom-qcs6490.inc` 的 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS` 还包括
`kernel-modules`、`fastrpc`、`modemmanager`、`networkmanager-*`、`pd-mapper` 等。

## 内核（linux-qcom-custom）

配方 `meta-radxa-dragon/recipes-kernel/linux/linux-qcom-custom_6.6.bb`：

- 源：`github.com/radxa/kernel.git`，分支 `kernel.qclinux.1.0.r1-rel`，SRCREV `2e366d0`
- 默认配置：`KERNEL_CONFIG ??= "qcom_defconfig"` + 片段 `qcom_addons.config`
- SELinux/SMACK 配置片段按 `DISTRO_FEATURES` 条件加入
- 含若干 QCLINUX 补丁（msm_display.ko、禁用 eMMC ICE、UFS devfreq 修复等）
- `msm` 模块默认 blacklist；另生成不含 GPU 的 `msm_display.ko`

> 内核里启用了哪些 WiFi/BT 相关 CONFIG，见 [driver-wifi-bt-aic8800d80](driver-wifi-bt-aic8800d80.md)。

## 引导固件（SPI NOR）必须配套 LE/QCLINUX，勿用 WP(Windows)

本板从 **SPI NOR** 引导（PBL→XBL→UEFI→内核），该套引导固件**不在** kas/UFS 刷写范围内。Radxa 发
两套互不兼容的 flat_build：**LE/QCLINUX**（Linux，HYP=Gunyah `hypvm.mbn`、UEFI 发设备树）与
**wp_*（Windows Platform）**（HYP=`hyp.mbn`、UEFI 发 ACPI/SMBIOS）。本仓库构建的是 QCLINUX/LE HLOS，
**只能配 LE 套件的 spinor**；若 SPI 残留 WP 引导固件，内核早期静默挂死、热复位入 dload（即 bring-up 时
「全量刷 UFS 仍不启动」的真因——UFS 刷写不碰 SPI NOR）。判别与刷写见
[flashing](../topics/flashing.md)（含 LE vs WP 对照表与 `flash-edl.sh` 防呆）。

## 设备树（dtb）来源与修复

内核设备树**不由 UEFI 提供也不从 dtb 分区加载**——这版预编译 UEFI 把旧 stock dtb 写死在固件里
经 EFI 配置表交给内核，导致 USB/GPU/VPU/display 全废。修法：用 `OSTREE_DEPLOY_DEVICETREE` 让
OSTree 在 systemd-boot 启动条目写出 `devicetree` 行，指向构建出的 `combined-dtb.dtb`（含
`qcm6490-graphics/video.dtbo` 叠加）覆盖固件内嵌树。本机机器配置据此新增：

- `OSTREE_DEPLOY_DEVICETREE:forcevariable = "1"`
- `OSTREE_DEVICETREE:forcevariable = "combined-dtb.dtb"`

（均须 `:forcevariable`——distro 用硬 `=` 写死且解析在后；`combined-dtb.dtb` 由本 layer
`linux-qcom-mergedtb` 补的 `do_deploy` 投到 `DEPLOY_DIR_IMAGE`。）

> 机制、两个坑、验证锚点与真机结果，全在 **[dtb-and-boot-devicetree](../topics/dtb-and-boot-devicetree.md)**。

## 同 layer 的另一机器

`qcs9075-radxa-airbox-q900`（AIRbox Q900）也由 meta-radxa-dragon 提供，但不在本仓库
target 范围内。

## 相关
- [driver-wifi-bt-aic8800d80](driver-wifi-bt-aic8800d80.md)
- [layers](layers.md)
- [distro-and-images](../topics/distro-and-images.md)
- [flashing](../topics/flashing.md) — SPI 引导固件 LE vs WP、edl-ng/qdl 刷写
- [dtb-and-boot-devicetree](../topics/dtb-and-boot-devicetree.md) — dtb 来源与 OSTREE_DEPLOY_DEVICETREE 修复
