## Context

魅族 E3 是一块 39pin MIPI-DSI 屏，集显示、触摸、背光于一体。在 QCS6490 的 mainline drm/msm 栈下：

- 显示：QCLINUX BSP 6.6.90 的 `drivers/gpu/drm/panel/` 是「一型一驱」，没有通用 DSI panel driver，必须随包发一个 OOT 驱动 `panel_meizu_e3`（`compatible = "meizu,e3-panel"`）。
- 触摸：三星 SEC 触摸 IC，OOT 驱动 `sec_ts`，固件 `.i` 直接 `#include` 进 `.ko`。
- 背光：屏自带 SGM37604A I2C 背光芯片，OOT 驱动 `sgm37604a`。
- 设备树：QCS6490 启动链（UEFI → systemd-boot → 内核 EFI-stub）不支持运行时 dtb overlay，面板节点必须在**构建期**合并进 base dtb。

这些素材已在外部参考工程（flange 的 `meizu-e3-panel` 包）就绪：三套驱动源码、`sec_ts` 固件、以及一份针对 Q6A 的 `.dtso`（接线依据原理图 v1.21，注释完备）。本变更的任务是把它们「翻译」成本仓库的 kas/Yocto 形态，并做成**可选、可组合、自包含**的一层。

本仓库已有的两个关键现成机制必须复用、不重造：

1. `linux-qcom-mergedtb`（meta-radxa-dragon）用 `fdtoverlay` 把 `KERNEL_TECH_DTBOS[<machine>]` 列出的所有 `.dtbo` 顺序叠进 base dtb，产出 `combined-dtb.dtb`。
2. `OSTREE_DEPLOY_DEVICETREE`（已在机器配置开启，见 `boot-devicetree` 能力）把 `combined-dtb.dtb` 写进 systemd-boot 启动条目，让内核真正用上它。

面板 dtbo 只要挤进第 1 步的输入列表，就会自动流经第 2 步进固件——无需任何新机制。

## Goals / Non-Goals

**Goals:**
- 用一个自包含 meta 层 `meta-mipi-panel` 提供 E3 屏的显示/触摸/背光适配。
- 用一个 kas 片段 `meizu-e3-panel.yml` 实现「可选叠加」：`kas build kas-radxa-q6a.yml:meizu-e3-panel.yml` 出带屏固件；不叠加则基线不变。
- 面板接线放进面板层自身，做到「包含 layer = 启用面板」，kas 片段极简。
- 复用现有 DTB 合并/部署管线，不改 `linux-qcom-mergedtb` 配方源（dtbo 登记走本层 bbappend）。
- i2c SE 固件 `qupv3fw.elf` 作为板级能力放入 `meta-radxa-dragon`（板层有意改动），不混进面板层。

**Non-Goals:**
- 不适配 rock5b / cubie-a7a 等其他载板（flange 包里那两份 `.dtso` 不纳入本 layer）。
- 不改动基线固件的任何默认行为。
- 不在本变更内追求精细电源管理（沿用 `.dtso` 中 `regulator-always-on` 的 bring-up 策略）。
- 不重写或上游化三块 OOT 驱动，原样拷入。

## Decisions

### 决策 1：dtbo 接线放 `layer.conf`；varflag 经 bbappend 增广（A 证伪后的最终方案）

**背景与解析顺序**：`KERNEL_TECH_DTBOS[...]` 在机器配置里是硬 `=` 赋值，而本仓库解析顺序是 `layer.conf → local.conf → machine → distro`（machine 在后）。任何普通赋值或写在 kas `local_conf_header` 的值都会被 machine 的 `=` 覆盖——这正是 dtb 修复时踩过的坑。

**原计划 A（已证伪）**：`KERNEL_TECH_DTBOS[<machine>]:append = " meizu-e3-panel.dtbo"` 写进 `layer.conf`，指望 `:append` 延后求值盖过 machine 的 `=`。**实测失败**：bitbake 的 ConfHandler 不支持「varflag 的 `:append`」，该行直接报 `unparsed line` 解析失败。

**最终方案（实施采用）**：分两处——
- 三项**普通变量**接线仍放 `layer.conf`（ConfHandler 支持普通变量的 `:append`），并用 `:qcs6490-radxa-dragon-q6a` override 收口：
  ```python
  KERNEL_TECH_DTBO_PROVIDERS:append:qcs6490-radxa-dragon-q6a = " meizu-e3-panel"
  IMAGE_INSTALL:append:qcs6490-radxa-dragon-q6a            = " meizu-e3-panel"
  KERNEL_MODULE_AUTOLOAD:append:qcs6490-radxa-dragon-q6a   = " panel_meizu_e3 sgm37604a sec_ts"
  ```
- **varflag 的增广**改由本层的 `recipes-kernel/images/linux-qcom-mergedtb.bbappend` 用 anonymous python 完成：
  ```python
  python () {
      machine = "qcs6490-radxa-dragon-q6a"
      if d.getVar("MACHINE") != machine:
          return
      cur = (d.getVarFlag("KERNEL_TECH_DTBOS", machine) or "").split()
      if "meizu-e3-panel.dtbo" not in cur:
          cur.append("meizu-e3-panel.dtbo")
          d.setVarFlag("KERNEL_TECH_DTBOS", machine, " ".join(cur))
  }
  ```
  recipe 解析发生在所有 conf（含 machine）之后，`d` 已含机器配置设好的 varflag 值，读出再追加即 parse 顺序安全、不丢机器原有 dtbo。这是 mergedtb 真正消费该 varflag 的配方，augment 在此最贴近消费点。

**实测确认**：`bitbake -e linux-qcom-mergedtb` 得 `KERNEL_TECH_DTBOS[qcs6490-radxa-dragon-q6a] = "qcm6490-graphics.dtbo qcm6490-video.dtbo meizu-e3-panel.dtbo"`；bbappend 正确匹配 mergedtb（不在 dangling 列表）。

**备选（未采用）**：kas 片段 `local_conf_header` 注入——被 machine 硬 `=` 覆盖、且接线散在仓库外不内聚，否决。

### 决策 2：单一配方 `meizu-e3-panel`，`inherit module deploy`，一次产出 3 ko + 1 dtbo

**选择**：面板是一个物件，用一个配方。`inherit module deploy`：

- `do_compile`：先建三块内核模块，再把 `.dtso` 经 `cpp` 预处理 + `dtc -@` 编成 `meizu-e3-panel.dtbo`。
- `do_install`：标准 module 安装，三块 `.ko` 进 `lib/modules/<ver>/updates/`。
- `do_deploy`：把 `meizu-e3-panel.dtbo` 投到 `DEPLOY_DIR_IMAGE/tech_dtbs/`（与 `qcom-graphicsdevicetree` 同款落点，供 mergedtb 取用）。

三块模块用一个**新写的根 Makefile** 递归子目录（kbuild 原生支持 `obj-m += <subdir>/`），三个子目录的 `.c/.h/.i/Makefile` 从 flange 原样拷入、不改：

```makefile
obj-m += panel_meizu_e3/
obj-m += sec_ts/
obj-m += sgm37604a/
```

**为什么**：贴合「面板=一个东西」的心智；`KERNEL_TECH_DTBO_PROVIDERS` 引用的 `<recipe>:do_deploy` 由本配方的 `do_deploy` 满足，provider 与驱动同源，依赖链清晰。`dtc` 取 `dtc-native`（或内核 `scripts/dtc/dtc`），与 `linux-qcom-mergedtb` 用 `dtc-native` 一致。

**备选**：拆成「三驱动配方 + 一 dtbo 配方」——更教科书但更碎，与用户「一个面板一个配方」诉求相悖。否决。

### 决策 3：layer 起步用同级本地路径，仿 `meta-radxa-dragon` 约定

**选择**：`meizu-e3-panel.yml` 用 `path: ../meta-mipi-panel`（同级本地副本）做开发与调试；稳定后再推远端 git 并锁 commit。

**为什么**：这是 CLAUDE.md 唯一允许的工程外引用形态（同级相对路径、可移植），且与 `meta-radxa-dragon` 现有「本地调试 ↔ 远端锁定」的切换约定完全对齐。

### 决策 4：OOT Makefile 的 `KSRC` 适配

三个子 Makefile 用 `KSRC ?=` 指向内核源，而 `module.bbclass` 以 `-C ${STAGING_KERNEL_DIR} M=${S}` 调 make。命令行的 `-C`/`M` 会覆盖 Makefile 的 `?=`，预期可直接编；若不然，在配方加 `EXTRA_OEMAKE += "KSRC=${STAGING_KERNEL_DIR}"` 兜底。

## Risks / Trade-offs

- **[varflag 的 `:append` 可能不生效]**（决策 1 的核心不确定点）→ 实施首步用 `bitbake -e` 确认最终 `KERNEL_TECH_DTBOS[qcs6490-radxa-dragon-q6a]` 同时含三个 dtbo；不生效则切 fallback C（bbappend mergedtb）。
- **[base dtb 未导出 overlay 引用的 label]**：`.dtso` 引用 `&mdss_dsi`、`&i2c13`、`&tlmm`、`&vreg_l6b_1p2` 等，`fdtoverlay` 需靠 base 的 `__symbols__` 解析 → graphics/video dtbo 已能合并，证明 `__symbols__` 在；但具体 label 仍需 `fdtoverlay -v` 实测确认无 `could not find target` 报错。
- **[i2c-geni 需要 `qupv3fw.elf`]【已坐实并修复】**：真机 dmesg 证实 i2c13(a94000.i2c) 带 `qcom,load-firmware`，geni_i2c 找不到 `/lib/firmware/qupv3fw.elf`（-2）→ 总线 deferred → 背光/触摸/面板全 deferred → 屏黑。本板 SE5 未被 bootloader 预配为 I2C（运行时实测：补固件后 `Firmware load for I2C protocol is Success`），故 `qcom,load-firmware` 必需、不能删。upstream linux-firmware **无** qcs6490 版 qupv3fw.elf（只有 sa8775p），它仅存在于 `firmware-qcom-bootbins`(QCM6490_bootbinaries) 且只 deploy 不进 rootfs。**修复**：新增配方 `qcom-qupv3fw-rootfs`（`recipes-bsp/qup-firmware/`）从 `DEPLOY_DIR_IMAGE/qupv3fw.elf` 装进 rootfs `/lib/firmware/qupv3fw.elf`（非 symlink，是实文件），经 layer.conf `IMAGE_INSTALL`(Q6A override) 进镜像。
- **[panel 模块加载时序]**：drm/msm DSI host 要在 panel 驱动注册后才出图 → 已挂 `KERNEL_MODULE_AUTOLOAD`；若仍黑屏，考虑把 `panel_meizu_e3` 纳入 initramfs。先实测。
- **[只验证构建，未必能上真机]**：本变更范围聚焦「能正确构建出带面板节点的固件」；真机点屏属后续 bring-up，受 risk 2/3/4 影响，留作开放验证项。

## Migration Plan

1. 在本仓库同级新建 `../meta-mipi-panel`，从 flange 拷入驱动源与 `.dtso`，写 `layer.conf`、配方、根 Makefile。
2. 写 `meizu-e3-panel.yml`。
3. `kas dump kas-radxa-q6a.yml:meizu-e3-panel.yml` 看解析；`bitbake -e` 验证 varflag（决策 1）。
4. `kas build kas-radxa-q6a.yml:meizu-e3-panel.yml`，检查三 `.ko`、`tech_dtbs/meizu-e3-panel.dtbo`、`combined-dtb.dtb` 含面板节点。
5. 回填 wiki 并在 `wiki/log.md` 记一条。

**回滚**：本变更对基线零侵入；不组合 `meizu-e3-panel.yml` 即等于回滚。

## Open Questions

- ~~决策 1 的 varflag `:append` 是否生效？~~ **已解决**：不生效（ConfHandler 不支持 varflag 的 `:append`），改用 bbappend anonymous python 增广，已实测通过。
- ~~`qupv3fw.elf` 是否必须由本 layer 提供？~~ **已解决（真机坐实）**：必须；通过新配方 `qcom-qupv3fw-rootfs` 把它装进 rootfs。见上方 Risks 对应条目。
- `panel_meizu_e3` 是否需进 initramfs 才能稳定点屏？（真机 bring-up 阶段确认）
- 三块 OOT 模块是否都能干净编出、面板节点是否能被 `fdtoverlay` 成功合进 `combined-dtb.dtb`（base dtb 是否导出所需 label）？需一次完整 `kas build` 验证（任务 4.2–4.5），尚未执行。
