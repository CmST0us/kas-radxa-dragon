# DTB 来源与启动设备树修复（OSTREE_DEPLOY_DEVICETREE）

_最后更新：2026-06-07_

本页讲清楚 Radxa Dragon Q6A 的**内核设备树（dtb）从哪来**，以及如何修复「UEFI 内嵌旧 dtb
导致 USB/GPU/VPU/display 全废」的问题。病灶定位的取证过程见 [log](../log.md) 2026-06-06 多条
finding；本页是**结论与落地方案**（change `fix-dtb-via-ostree-devicetree`，2026-06-07 真机验证通过）。

## 一、病灶（结论）

启动链：

```
UEFI(SPF 预编译, FV 内嵌 stock dtb 138KB)
   │  经 DtbBuffer → EFI 配置表(DEVICE_TREE_GUID)
   ▼
systemd-boot 255.17 → 读 OSTree 管理的 type-1 条目 ostree-1+3.conf
   │  条目原本只有 linux + initrd，❌ 无 devicetree 行
   ▼
内核 arm64 EFI-stub (drivers/firmware/efi/libstub/fdt.c)
   └─ cmdline 无 dtb=、条目无 devicetree → 从 EFI 配置表取树
       = UEFI 内嵌的旧 stock 138KB 树（错）→ USB/GPU/VPU/display 全废
```

- 正确的 dtb（构建产物 `combined-dtb.dtb`，238KB）虽刷进了 `dtb_a` 分区，但**这版 UEFI 不读分区**。
- UEFI 是签名预编译 blob、无开关、不可重编 → **不能从固件侧修**，只能在启动条目里把正确 dtb 喂给内核。

## 二、修法：让 OSTree 在启动条目写出 `devicetree` 行

打开 `OSTREE_DEPLOY_DEVICETREE`，OSTree 会把指定 dtb 部署进启动目录，并由 libostree 在
type-1 条目里写出 `devicetree` 行覆盖固件内嵌树（内核 EFI-stub 改从配置表用此树；UEFI 的
`EFI_DT_FIXUP_PROTOCOL` 还会做内存等运行时修正）。全链路：

```
OSTREE_DEPLOY_DEVICETREE=1  +  OSTREE_DEVICETREE=<dtb>
  → ostree-kernel-initramfs do_install
      拷 dtb → /usr/lib/modules/<ver>/dtb/ 与 .../devicetree
  → ostree admin deploy (image_types_ota.bbclass)
      libostree 探到 devicetree 文件
  → install_deployment_kernel 设 bootconfig "devicetree"
  → ostree-bootconfig-parser.c (qcom 的 0007-sort-key.patch 后 fields[] 含 "devicetree")
      → ostree-1+3.conf 写出  devicetree /ostree/.../devicetree
```

> `OSTREE_BOOTLOADER="none"` 不挡路：BLS 条目由 libostree 核心 `install_deployment_kernel` 写，
> 与 bootloader backend 无关。

## 三、两个必须绕过的坑（实施中发现）

### 坑 1：distro 用硬 `=` 写死，必须 `:forcevariable`

`meta-qcom-distro/conf/distro/include/qcom-base.inc` 硬赋值：

```
OSTREE_DEPLOY_DEVICETREE = "0"
OSTREE_DEVICETREE = "${KERNEL_DEVICETREE}"
OSTREE_MULTI_DEVICETREE_SUPPORT = "0"
```

poky `bitbake.conf` 解析顺序是 `local.conf` → `machine` → `distro`，**distro 最后解析**，普通 `=`
会被它盖回。→ 无论放 local.conf 还是 machine conf，都必须用 `:forcevariable`（最高优先级覆盖、
不受解析顺序影响）。**实测坐实**：用普通 `=` 时条目始终无 `devicetree` 行。

### 坑 2：`OSTREE_DEVICETREE` 默认值在该配方里为空，必须显式设

默认 `OSTREE_DEVICETREE = "${KERNEL_DEVICETREE}"`，但本机 `KERNEL_DEVICETREE` 是
**`:pn-linux-qcom-custom` 限定**（machine conf），只对内核配方生效。`ostree-kernel-initramfs`
配方里 `KERNEL_DEVICETREE` 未定义 → `OSTREE_DEVICETREE` 解析为空 → `do_install` 的 devicetree
分支因 `-n` 判空被跳过。→ 必须 `OSTREE_DEVICETREE:forcevariable` 显式给非空 dtb 名（`do_install`
用 `basename` 取文件，给扁平名即可）。

### 坑 3：须部署 `combined-dtb.dtb`（含叠加），不是裸树

| 部署哪棵 | USB | GPU(zap) | VPU(venus) |
|---|---|---|---|
| 裸 `qcs6490-radxa-dragon-q6a.dtb`（231KB，已在 DEPLOY_DIR_IMAGE） | ✅ | ❌ | ❌ |
| `combined-dtb.dtb`（238KB，含 graphics/video 叠加） | ✅ | ✅ | ✅ |

`combined-dtb.dtb` 由 `linux-qcom-mergedtb` 用 `fdtoverlay` 把 `qcm6490-graphics.dtbo` +
`qcm6490-video.dtbo` 合并到裸树而成，但该配方原本只 `do_install` 进包、**不 deploy 到
DEPLOY_DIR_IMAGE** → 须给它补 `do_deploy`，否则 `ostree-kernel-initramfs` 拷不到。

## 四、落地改动（均在本地副本 meta-radxa-dragon）

| 文件 | 改动 |
|---|---|
| `conf/machine/qcs6490-radxa-dragon-q6a.conf` | `OSTREE_DEPLOY_DEVICETREE:forcevariable="1"`、`OSTREE_DEVICETREE:forcevariable="combined-dtb.dtb"` |
| `recipes-kernel/images/linux-qcom-mergedtb.bb` | 加 `inherit deploy` + `do_deploy`（投 `combined-dtb.dtb` 到 `DEPLOY_DIR_IMAGE`）+ `addtask deploy after do_compile before do_build` |
| `recipes-sota/ostree-kernel-initramfs/ostree-kernel-initramfs_%.bbappend`（新建） | `do_install[depends] += "linux-qcom-mergedtb:do_deploy"`，保证拷贝时 dtb 已就位 |

> 板级改动落本地副本时 kas 需切本地开发模式（`path: ../meta-radxa-dragon`），见
> [versioning](versioning.md)。层优先级 radxa-dragon(7) > qcom-hwe(6)，本地副本的 mergedtb 胜出。

## 五、验证锚点

**构建层**（刷机前即可查）：

- `ostree-*.conf` 出现 `devicetree /ostree/.../devicetree-<ver>` 行；
- 部署的 `…/modules/<ver>/devicetree` 与 `DEPLOY_DIR_IMAGE/combined-dtb.dtb` 同为 238428B。

**真机**（adb 实测，2026-06-07）：

| 设备 | 结果 |
|---|---|
| `/sys/firmware/fdt` | 240545B（= 238428 combined + UEFI fixup 约 2KB），model=Radxa Dragon Q6A |
| USB | `dwc3 a600000.usb`、adb 连通 |
| GPU | `kgsl-3d0` bound、`gpu_model=Adreno643v1`、无 zap 报错 |
| VPU | `msm_vidc` 载固件、`iris_vpu` bound、`/dev/video32`/`video33` |
| display | `card0` + HDMI-A-1 + renderD128 |

> 残留一行 `msm_dpu: no GPU device was found` 是 **KGSL（下游 GPU 驱动）与 mainline DRM 架构分离**
> 的良性提示——GPU 经 KGSL 工作、display 经 DPU 工作，互不为对方的 DRM 组件。与本 dtb 修复无关，
> dtb 改不了它。

## 相关
- [log](../log.md) — 病灶取证（2026-06-06）与本次修复（2026-06-07 change）
- [machine-qcs6490-radxa-dragon-q6a](../components/machine-qcs6490-radxa-dragon-q6a.md) — dtb 来源与机器配置
- [flashing](flashing.md) — 刷机；DTB 来源相关取证
- [versioning](versioning.md) — 本地↔远端切换
