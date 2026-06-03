# AIC8800D80 WiFi/BT 驱动与固件

_最后更新：2026-06-03_

Radxa Dragon Q6A 上的 AICSemi **AIC8800D80**（USB 接口）WiFi + 蓝牙模组的支持情况。

## 结论速览

| 部分 | 状态 |
|---|---|
| 内核驱动（WiFi/BT 模块） | ✅ in-tree 编译，随 `kernel-modules` 进镜像 |
| 固件 | ✅ 已修复——经机器配置拉入（原为孤立配方，默认不进镜像） |

## 1. 内核驱动（in-tree）

驱动源码在 radxa 内核 fork（见 [machine 页](machine-qcs6490-radxa-dragon-q6a.md) 的内核小节）：

```
drivers/net/wireless/aic/aic8800_usb/
  ├─ aic8800_fdrv/   → WiFi 主驱动 (aic8800_fdrv.ko)
  └─ aic_load_fw/    → 固件加载器
```

`qcom_defconfig` 中启用：

```
CONFIG_WLAN_VENDOR_AIC=y
CONFIG_AIC_WLAN_AIC8800_USB=y
CONFIG_AIC8800_WLAN_SUPPORT=m      # WiFi 驱动模块
CONFIG_AIC_LOADFW_SUPPORT=m        # 固件加载模块
CONFIG_BT_AIC_BTUSB=m              # 蓝牙 USB 模块
```

均为 `=m`，而机器配置含 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += kernel-modules`，故 `.ko`
会随镜像安装。

## 2. 固件

固件配方 `meta-radxa-dragon/recipes-kernel/wifibt-firmware/wifibt-firmware.bb`：
- 源：`github.com/radxa/rkwifibt.git`（branch `develop`，SRCREV `4c7ba27`）
- 安装到 `/lib/firmware/aic8800D80/`（`fmacfw_8800d80_*.bin`、`fw_patch_*`、蓝牙
  `fw_adid` / `fw_ble_scan` 等）
- 包名：`wifibt-firmware-aic8800d80-usb`

### 原问题与修复
- **原问题**：该配方未被任何 machine/image 引用（孤立配方），固件默认不进镜像 →
  驱动能加载但芯片不工作。
- **修复**（2026-06-03，commit `b82b968`，未 push）：在机器配置
  `qcs6490-radxa-dragon-q6a.conf` 增加
  ```
  MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += " wifibt-firmware-aic8800d80-usb"
  ```
  用软依赖 RRECOMMENDS，与驱动模块进同一镜像。

## 注意事项
- 本套驱动/固件针对 **USB** 接口的 AIC8800D80；若实际为 SDIO 版本则需另一套（固件文件不同）。
- 回切 `meta-radxa-dragon` 到远端前，须先 push 本改动并更新锁定 commit，见
  [versioning](../topics/versioning.md)。

## 验证
```bash
cd /home/eki/Project/carbon/kas-radxa-dragon
kas shell kas-radxa-q6a.yml -c "bitbake -g qcom-multimedia-image && grep aic8800 pn-depends.dot"
```

## 相关
- [machine-qcs6490-radxa-dragon-q6a](machine-qcs6490-radxa-dragon-q6a.md)
- [build-and-dev-workflow](../topics/build-and-dev-workflow.md)
