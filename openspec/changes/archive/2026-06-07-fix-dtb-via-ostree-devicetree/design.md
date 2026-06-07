## Context

启动链现状（已由 `wiki/log.md` 多条 finding 坐实）：

```
UEFI(SPF 预编译, FV 内嵌 stock dtb 138KB)
   │  经 DtbBuffer → EFI 配置表(DEVICE_TREE_GUID)
   ▼
systemd-boot 255.17
   │  读 /boot/loader/entries/ostree-1.conf (OSTree 管理的 type-1 条目)
   │  条目只有 linux + initrd，❌ 无 devicetree 行
   ▼
内核 arm64 EFI-stub (drivers/firmware/efi/libstub/fdt.c)
   ├─ cmdline 有 dtb=?  → 无
   ├─ 配置表有 dtb?     → 有，但是 UEFI 内嵌的旧 stock 树（错）
   └─ 结果：用错树 → USB/GPU/VPU/display 全废
```

正确的 dtb（本工程构建产物 `combined-dtb.dtb`，238KB，带 `qcom,dwc3`/zap shader/`msm-id`）虽已刷进 `dtb_a` 分区，但**这版 UEFI 不读分区**，白躺着。UEFI 是签名预编译 blob、无开关、不可重编，故只能在启动条目侧把正确 dtb 喂给内核。

约束：

- 板级改动落入本地副本 `../meta-radxa-dragon`；kas 切回本地开发模式。
- 所有 `kas build` / `bitbake` 由用户本人执行。
- 改动须可逆；单条目误改不启动时用 EDL 兜底重刷。

## Goals / Non-Goals

**Goals：**

- 让 `ostree-1.conf` 长出 `devicetree` 行，内核启动用本工程部署的 dtb 覆盖固件内嵌树。
- 部署的 dtb 为合并 graphics/video 叠加后的 `combined-dtb.dtb`，使 USB/GPU/VPU/display 一并恢复。
- 分两步：先证链路（USB 回来），再补全（GPU/VPU/display）。

**Non-Goals：**

- 不改 UEFI 固件、不走「让 UEFI 读 dtb 分区」路线（已验证不可行）。
- 不采用 cmdline `dtb=` 方案（路径 B）—— 本提案只做路径 A。
- 不代为执行构建与刷机。

## Decisions

### 决策 1：用路径 A（`OSTREE_DEPLOY_DEVICETREE`），不用路径 B（cmdline `dtb=`）

链路已代码级坐实可行：

```
OSTREE_DEPLOY_DEVICETREE=1
  → ostree-kernel-initramfs_0.0.1.bb:51-60
      把 OSTREE_DEVICETREE 列的 dtb → /usr/lib/modules/<ver>/dtb/<name>
      单树模式(MULTI=0) 再拷第一个 → /usr/lib/modules/<ver>/devicetree
  → ostree admin deploy (image_types_ota.bbclass:54)
      libostree get_kernel_layout 探到 devicetree 文件
  → install_deployment_kernel 设 bootconfig "devicetree"
  → ostree-bootconfig-parser.c (0007-sort-key.patch 后)
      fields[] 含 "devicetree" → ostree-1.conf 写出 devicetree 行
```

- **为什么不用路径 B**：cmdline `dtb=` 需自管 dtb 落 ESP 与路径稳定性，较脆；路径 A 是 OSTree/OTA 原生机制，随部署自动管理。
- **`OSTREE_BOOTLOADER="none"` 不挡路**：`image_types_ota.bbclass:29` 的 `set sysroot.bootloader none` 只影响 grub/uboot 后处理，BLS 条目由 `install_deployment_kernel` 写，与 backend 无关。

### 决策 2：部署 `combined-dtb.dtb`，不用默认裸树

`OSTREE_DEVICETREE` 默认 `= ${KERNEL_DEVICETREE}` = 裸 `qcs6490-radxa-dragon-q6a.dtb`。`linux-qcom-mergedtb.bb` 已确认：zap shader/venus 来自 `qcm6490-graphics.dtbo` + `qcm6490-video.dtbo` 的 `fdtoverlay` 合并，裸树没有。

| 部署哪棵 | USB | GPU(zap) | VPU(venus) |
|---|---|---|---|
| 裸 `qcs6490-…-q6a.dtb`（默认） | ✅ | ❌ | ❌ |
| `combined-dtb.dtb`（合并后） | ✅ | ✅ | ✅ |

→ 必须指向 `combined-dtb.dtb`。本机 `KERNEL_DEVICETREE` 只有一棵树，故 `combined-dtb.dtb` 是单个 FDT（非多树拼接），可直接交内核，`OSTREE_MULTI_DEVICETREE_SUPPORT=0` 取第一个即它，无影响。

### 决策 3：给 `linux-qcom-mergedtb` 补 `do_deploy`

`ostree-kernel-initramfs.bb:55` 是 `cp ${DEPLOY_DIR_IMAGE}/<basename>`，但 `linux-qcom-mergedtb.bb` 只有 `do_install`（进包/镜像→dtb 分区），**未把 `combined-dtb.dtb` 投到 `DEPLOY_DIR_IMAGE`**。直接指过去会因源文件缺失而失败。

- **方案**：给本地副本的 `linux-qcom-mergedtb.bb` 补 `do_deploy`，将 `combined-dtb.dtb` 投到 `DEPLOY_DIR_IMAGE`；并让 `ostree-kernel-initramfs` 依赖 `linux-qcom-mergedtb:do_deploy`（其 `do_install[depends]` 已依赖 `virtual/kernel:do_deploy`，按需追加）。
- **备选（未采用）**：改 `ostree-kernel-initramfs` 的拷贝源——侵入面更大、动到通用 layer 逻辑，不如在板级配方补 deploy 干净。

### 决策 3.5（实施中发现）：必须用 `:forcevariable` 覆盖 distro 的硬赋值

`meta-qcom-distro/conf/distro/include/qcom-base.inc:94-96` 用**硬赋值**写死了：

```
OSTREE_DEPLOY_DEVICETREE = "0"
OSTREE_DEVICETREE = "${KERNEL_DEVICETREE}"
OSTREE_MULTI_DEVICETREE_SUPPORT = "0"
```

而 poky `bitbake.conf` 的解析顺序是 `local.conf`(827) → `machine`(829) → `distro`(831)。distro 最后解析，硬 `=` 会盖掉前面 local.conf / machine conf 里的普通 `=`。

→ **实测坐实**：Step 1 把 `OSTREE_DEPLOY_DEVICETREE = "1"` 放进 local.conf，构建后 `ostree-1+3.conf` 仍无 `devicetree` 行——值被 distro 盖回 `0`。

**结论**：凡要覆盖这三个变量，无论放 local.conf 还是 machine conf，都必须用 `:forcevariable`（bitbake 最高优先级覆盖，不受解析顺序影响），例如 `OSTREE_DEPLOY_DEVICETREE:forcevariable = "1"`。

- **备选（未采用）**：自定义 distro 继承 qcom-wayland 再覆盖——对 bring-up 太重；或直接改 `meta-qcom-distro`——非本工程 layer，不应改。

### 决策 3.6（实施中发现）：必须显式设 `OSTREE_DEVICETREE`，默认值在该配方里为空

`OSTREE_DEVICETREE` 默认 `= "${KERNEL_DEVICETREE}"`，但本机 `KERNEL_DEVICETREE` 是 **`:pn-linux-qcom-custom` 限定**（machine conf），只在内核配方 `linux-qcom-custom` 生效。`ostree-kernel-initramfs` 配方里 `KERNEL_DEVICETREE` 未定义 → `OSTREE_DEVICETREE` 解析为空。

**实测坐实**：即便 `OSTREE_DEPLOY_DEVICETREE:forcevariable=1` 生效（`run.do_install` 里 `[ True = True ]`），devicetree 分支因第二个条件 `[ -n "${KERNEL_DEVICETREE}" ]`（展开为空的 shell 变量）判空而被跳过，不生成 `devicetree` 文件、条目也无 `devicetree` 行。

**结论**：必须用 `OSTREE_DEVICETREE:forcevariable` 显式给非空 dtb 名。`do_install` 用 `basename` 取文件，故给扁平名即可：

- Step 1：`qcs6490-radxa-dragon-q6a.dtb`（裸树，231KB，已在 `DEPLOY_DIR_IMAGE`，无需改配方）。
- Step 2：`combined-dtb.dtb`（含 graphics/video 叠加，~238KB），需配 `do_deploy`（决策 3）。

这把原「Step 1 用默认裸树」修正为「Step 1 显式指裸树」——两步结构不变，Step 1 仍无需改配方。

### 决策 4：板级改动落本地副本，kas 切本地开发模式

- machine conf 与 mergedtb 配方改动放 `../meta-radxa-dragon`。
- `kas-radxa-q6a.yml` 把 `meta-radxa-dragon` 从远端锁定（`url/commit`）切到 `path: ../meta-radxa-dragon`。
- Step 1 的开关可先放 `local_conf_header` 快速验证（零配方改动、最易回滚），验证通过后再固化进 machine conf。

### 实施分层与 Agent Work Team

实施阶段按提案规约组建 Agent Work Team（产品 / 研发 / QA），用 Subagent 派发：研发产出配方与配置改动并具备产品思维，与产品反复打合；QA 以「构建产物可验证锚点 + 设备实测」把关。构建命令一律交用户执行。

## Risks / Trade-offs

- [Step 1 后 GPU/VPU 仍坏，被误判为方案无效] → 明确告知 Step 1 只验证「devicetree 行 + USB」，GPU/VPU 留待 Step 2。
- [`combined-dtb.dtb` 未进 `DEPLOY_DIR_IMAGE` 导致构建失败] → Step 2 先落 `do_deploy` 再切 `OSTREE_DEVICETREE`，并以「构建到 ostree-kernel-initramfs 不报缺文件」为门禁。
- [单条目误改导致设备不启动] → 改动可逆；保留 EDL 兜底重刷流程（见 `wiki/topics/flashing.md`）。
- [切本地开发模式后与远端锁定漂移] → 验证稳定后，按 `wiki/topics/versioning.md` 决定是否回推远端并重新锁定 commit。
- [libostree 是否真写 devicetree 行的最终确证] → 以 OTA sysroot 的 `ostree-1.conf` 实查为准（构建后、刷机前即可验），不靠推断。

## Migration Plan

1. kas 切本地开发模式（`path: ../meta-radxa-dragon`）。
2. Step 1：开关 `OSTREE_DEPLOY_DEVICETREE=1`（先 `local_conf_header`）→ 用户构建 → 查 `ostree-1.conf` 有 `devicetree` 行 → 刷机验 USB。
3. Step 2：本地副本补 `do_deploy` + machine conf 设 `OSTREE_DEVICETREE="combined-dtb.dtb"` → 用户构建 → 查部署 dtb 字节 = `combined-dtb.dtb`（238KB）→ 刷机验 GPU/VPU/display。
4. 回填 wiki 并在 `log.md` 记录。
- **回滚**：还原 `OSTREE_DEPLOY_DEVICETREE=0` 与配方改动、kas 切回远端锁定即可；设备侧用 EDL 重刷上一可启动镜像。

## Open Questions

- `combined-dtb.dtb` 是否需同时处理 `combined-dtb-el2.dtb`（Gunyah/KVM EL2 树）？当前仅针对主 VM 启动，倾向只部署 `combined-dtb.dtb`，待 Step 2 实测确认 EL2 不受影响。
- 验证稳定后是否回推 `../meta-radxa-dragon` 改动到远端并重新锁定 commit —— 留给实施收尾决策。
