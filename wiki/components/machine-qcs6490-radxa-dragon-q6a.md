# Machine: qcs6490-radxa-dragon-q6a

_最后更新：2026-06-03_

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

## 同 layer 的另一机器

`qcs9075-radxa-airbox-q900`（AIRbox Q900）也由 meta-radxa-dragon 提供，但不在本仓库
target 范围内。

## 相关
- [driver-wifi-bt-aic8800d80](driver-wifi-bt-aic8800d80.md)
- [layers](layers.md)
- [distro-and-images](../topics/distro-and-images.md)
