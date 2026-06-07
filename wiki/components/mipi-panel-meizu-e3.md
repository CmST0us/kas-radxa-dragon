# meta-mipi-panel / 魅族 E3 MIPI-DSI 屏

_最后更新：2026-06-07_

魅族 E3 39pin MIPI-DSI 屏（显示 + 触摸 + 背光）在 Radxa Dragon Q6A 上的适配。由**可选、可组合**
的 meta 层 `meta-mipi-panel` 提供，通过 kas 片段叠加：

```bash
kas build kas-radxa-q6a.yml:meizu-e3-panel.yml
```

不组合 `meizu-e3-panel.yml` 时，基线固件与现状完全一致。来源 change：openspec
`add-meizu-e3-panel-layer`（已归档），真机点屏验证通过。

## 一、屏与三块驱动

魅族 E3 = s6d6ft0 Tianma FHD **1080×2160@60**，IC 自配置「傻屏」（主控只发 sleep-out +
display-on 两条 DCS）。QCS6490 mainline drm/msm 的 `drivers/gpu/drm/panel/` 是「一型一驱」、无通用
DSI panel 驱动，故随层发 OOT 驱动：

| 驱动 | 角色 | compatible | 备注 |
|---|---|---|---|
| `panel_meizu_e3` | 显示 | `meizu,e3-panel` | mainline drm_panel 风格最小骨架 |
| `sec_ts` | 触摸（i2c13 @0x48） | `sec,sec_ts` | 固件 `.i` 已 `#include` 进 `.ko`，无需单独固件包 |
| `sgm37604a` | 背光（i2c13 @0x36） | `sgmicro,sgm37604a` | 屏自带 SGM37604A I2C 背光芯片 |

源码与 `.dtso` 从外部参考工程（flange `meizu-e3-panel` 包）拷入本层自包含，不跨工程引用。

## 二、单一配方：3 ko + 1 dtbo

`recipes-kernel/meizu-e3-panel/meizu-e3-panel_1.0.bb`，`inherit module deploy`：

- `do_compile`：根 Makefile 递归 `obj-m += panel_meizu_e3/ sec_ts/ sgm37604a/` 建三模块；再
  `cpp` + `dtc -@` 把 `.dtso` 编成 `meizu-e3-panel.dtbo`。
- `do_install`：三 `.ko` 进 `lib/modules/<ver>/updates/`（`${PN}` 元包自动 RDEPENDS 三 `kernel-module-*` 包）。
- `do_deploy`：`meizu-e3-panel.dtbo` → `DEPLOY_DIR_IMAGE/tech_dtbs/`，供 mergedtb 取用。

## 三、设备树：复用现有合并管线，dtbo 登记走 bbappend

面板节点必须**构建期**合进 base dtb（QCS6490 启动链不支持运行时 overlay）。复用 meta-radxa-dragon
的 `linux-qcom-mergedtb`（见 [dtb-and-boot-devicetree](../topics/dtb-and-boot-devicetree.md)），把
`meizu-e3-panel.dtbo` 加进 `KERNEL_TECH_DTBOS[qcs6490-radxa-dragon-q6a]`，随 `combined-dtb.dtb`
经 `OSTREE_DEPLOY_DEVICETREE` 进固件。

> **关键坑**：`KERNEL_TECH_DTBOS` 是 varflag，bitbake ConfHandler **不支持其 `:append`**
> （`KERNEL_TECH_DTBOS[<machine>]:append=...` 解析失败）；普通赋值又被机器配置后解析的硬 `=` 覆盖。
> 故 dtbo 登记改由本层 `recipes-kernel/images/linux-qcom-mergedtb.bbappend` 的 anonymous python
> 读机器配置已设值后增广（recipe 解析在所有 conf 之后，parse 顺序安全，不丢机器原有 dtbo）。
> 其余三项接线（provider 登记、`IMAGE_INSTALL`、`KERNEL_MODULE_AUTOLOAD`）是普通变量 `:append`，
> 放 `conf/layer.conf`，均用 `:qcs6490-radxa-dragon-q6a` override 收口（非 Q6A 机器不误装）。

## 四、依赖板级固件 qupv3fw.elf（屏不亮的真因）

触摸/背光挂在 **i2c13（`a94000.i2c` = QUP1_SE5）**，该 SE 未被 bootloader 预配为 I2C，`.dtso`
给 i2c13 加了 `qcom,load-firmware`，内核 geni_i2c 需从 `/lib/firmware/qupv3fw.elf` 加载 SE 固件后
总线方能上线。

bring-up 时屏黑的完整因果链（真机 dmesg 坐实）：

```
rootfs 无 /lib/firmware/qupv3fw.elf
  → geni_i2c a94000.i2c: Direct firmware load for qupv3fw.elf failed -2
  → i2c-13 总线 deferred（platform a94000.i2c: deferred probe pending）
  → 0x36 背光 / 0x48 触摸 不出现
  → panel 的 backlight=<&sgm37604_bl> 等不到背光 → mipi-dsi ae94000.dsi.0 永久 deferred
  → DSI 不使能 → 屏黑
```

**根因**：upstream linux-firmware **无** qcs6490 版 qupv3fw.elf（只有 sa8775p），它仅存在于
Qualcomm 引导固件包 `firmware-qcom-bootbins`（QCM6490_bootbinaries）且只 deploy 到镜像目录、不进 rootfs。

**修复（板级能力，不在本面板层）**：把 qupv3fw.elf 装进 rootfs 是板级基础能力（任何声明
`qcom,load-firmware` 的 SE 都需要），故放在板层 **meta-radxa-dragon**：
- 配方 `recipes-bsp/qup-firmware/qcom-qupv3fw-rootfs_1.0.bb`：从 `DEPLOY_DIR_IMAGE/qupv3fw.elf`
  装进 rootfs `/lib/firmware/qupv3fw.elf`；
- 机器配置 `MACHINE_ESSENTIAL_EXTRA_RRECOMMENDS += " qcom-qupv3fw-rootfs"`（与 wifibt 固件同款）。

详见 [machine 页](machine-qcs6490-radxa-dragon-q6a.md)。补上固件后真机依次点亮：i2c-13 上线 →
sec_ts/sgm37604a probe → `panel-meizu-e3` 绑定 `ae94000.dsi.0` → weston 驱动 DSI-1 `1080x2160@60`。

## 五、版本锁定

- `meta-mipi-panel`：`github.com/CmST0us/meta-mipi-panel.git`，分支 `scarthgap`，commit `2b3fab3`
  （由 `meizu-e3-panel.yml` 远端锁定；本地调试切 `path: ../meta-mipi-panel`）。
- 板级固件依赖随 `meta-radxa-dragon` 升到 `7a0c513`（含 `qcom-qupv3fw-rootfs`），见 [layers](layers.md)。

## 相关
- [layers](layers.md) — 全部 layer 与锁定 commit
- [machine-qcs6490-radxa-dragon-q6a](machine-qcs6490-radxa-dragon-q6a.md) — qupv3fw 板级固件、机器配置
- [dtb-and-boot-devicetree](../topics/dtb-and-boot-devicetree.md) — combined-dtb 合并与部署管线
- [kas-configuration](../topics/kas-configuration.md) — kas 片段组合写法
