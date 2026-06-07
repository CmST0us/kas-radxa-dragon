## 1. 准备：切到本地开发模式

- [x] 1.1 在 `kas-radxa-q6a.yml` 把 `meta-radxa-dragon` 从远端锁定（`url`/`commit`/`branch`）切到本地 `path: ../meta-radxa-dragon`（其余 layer 不动）
- [x] 1.2 已确认本地模式生效（Step 2 期间 `build/conf/bblayers.conf` 指向 `${TOPDIR}/../../meta-radxa-dragon`、本地副本构建成功）；现已由 4.3 切回远端锁定 `e7cfe34`

## 2. Step 1：打开开关、验证链路（用默认裸 dtb）

- [x] 2.1 在 `kas-radxa-q6a.yml` 的 `local_conf_header` 临时加入 `OSTREE_DEPLOY_DEVICETREE:forcevariable = "1"` 与 `OSTREE_DEVICETREE:forcevariable = "qcs6490-radxa-dragon-q6a.dtb"`（两者都必须 `:forcevariable`；且必须显式设 `OSTREE_DEVICETREE`，其默认 `${KERNEL_DEVICETREE}` 在 ostree-kernel-initramfs 配方里为空）
- [x] 2.2 用户执行 `kas build kas-radxa-q6a.yml`（实施方不代为构建）
- [x] 2.3 构建后查 OTA sysroot 的 `ostree-*.conf`，确认出现 `devicetree` 行并指向已部署的 dtb 文件（已验证：`devicetree` 行出现）
- [x] 2.4 用户刷机并启动，验证 USB 恢复（已验证：adb 连通；`/sys/firmware/fdt`=233825B，model=Radxa Dragon Q6A，已换掉 138KB stock；UEFI fixup +约2KB）
- [x] 2.5 记录 Step 1 结论：`devicetree` 行出现 ✓、USB 恢复 ✓；GPU(`no GPU device`)/VPU(无 venus) 仍坏，需 Step 2 叠加层

## 3. Step 2：补 do_deploy 并指向 combined-dtb.dtb

- [x] 3.1 在本地副本 `../meta-radxa-dragon/recipes-kernel/images/linux-qcom-mergedtb.bb` 新增 `inherit deploy` + `do_deploy`（投 `combined-dtb.dtb` 到 `DEPLOYDIR`→`DEPLOY_DIR_IMAGE`）+ `addtask deploy after do_compile before do_build`
- [x] 3.2 新建 `../meta-radxa-dragon/recipes-sota/ostree-kernel-initramfs/ostree-kernel-initramfs_%.bbappend`，`do_install[depends] += "linux-qcom-mergedtb:do_deploy"`
- [x] 3.3 在本地副本 machine conf 设 `OSTREE_DEPLOY_DEVICETREE:forcevariable="1"` 与 `OSTREE_DEVICETREE:forcevariable="combined-dtb.dtb"`，并从 `local_conf_header` 移除 Step 1 临时块（已确认 bblayers 用的是本地副本、层优先级 7>6）
- [x] 3.4 用户执行 `kas build kas-radxa-q6a.yml`（实施方不代为构建）
- [x] 3.5 构建后确认：`combined-dtb.dtb` 已 deploy（238428B）、部署的 `devicetree` 文件 = 238428B（非 231KB 裸树）、条目有 `devicetree` 行
- [x] 3.6 用户刷机并启动，adb 实测全恢复：`/sys/firmware/fdt`=240545B（=238428 combined+fixup）；GPU=kgsl-3d0 bound、gpu_model=Adreno643v1、无 zap 报错；VPU=msm_vidc 载固件、/dev/video32/33、iris_vpu bound；display=card0+HDMI+renderD128。残留 `msm_dpu: no GPU device`=KGSL/DRM 架构分离的良性提示，与本改动无关

## 4. 收尾：回填 wiki 与版本决策

- [x] 4.1 回填 wiki：新建 `topics/dtb-and-boot-devicetree.md`（机制+两坑+验证主页面），更新 `components/machine-qcs6490-radxa-dragon-q6a.md`（dtb 来源/修复段+链接）与 `index.md`
- [x] 4.2 在 `wiki/log.md` 追加一条 `change` 记录（2026-06-07）
- [x] 4.3 回推远端并重新锁定：本地副本提交 `e7cfe34` 并 push `origin/scarthgap`；`kas-radxa-q6a.yml` 切回远端锁定 `commit: e7cfe34`；同步更新 CLAUDE.md 备忘与 wiki（layers/versioning/build-and-dev-workflow）的 commit 引用
