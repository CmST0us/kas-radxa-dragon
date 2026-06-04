# Layers 清单

_最后更新：2026-06-03_

`kas-radxa-q6a.yml` 管理的全部 layer。所有上游分支均为 `scarthgap`。
版本来源：原 manifest `qcom-6.6.90-QLI.1.5-Ver.1.1_qim-product-sdk-2.0.1.xml`。

> 真值来源是 `kas-radxa-q6a.yml`；下表如与之不符，以该文件为准（并触发一次 lint）。

## 仓库与锁定版本

| Layer 仓库 | 来源 | 锁定 commit | 启用的 layer |
|---|---|---|---|
| poky | git.yoctoproject.org/poky | `0ce88bc` | `meta`, `meta-poky`（含 bitbake） |
| meta-openembedded | github.com/openembedded | `6c9f1f8` | oe, python, perl, networking, multimedia, filesystems, gnome |
| meta-security | git.yoctoproject.org | `bc865c5` | 根 + `meta-tpm` |
| meta-selinux | git.yoctoproject.org | `4fbbcab` | 根 |
| meta-virtualization | git.yoctoproject.org | `94ee980` | 根 |
| meta-updater | github.com/uptane | `92f0e7a` | 根 |
| meta-tensorflow | git.yoctoproject.org | `1a0c74c` | 根 |
| meta-qcom | github.com/Linaro | `ec80a36` | 根（BSP） |
| meta-qcom-hwe | github.com/qualcomm-linux | `a5fdd68` | 根（机器定义所在） |
| meta-qcom-distro | github.com/qualcomm-linux | `08cc4b0` | 根（distro 定义所在） |
| meta-qcom-qim-product-sdk | github.com/qualcomm-linux | `eb937f9` | 根 |
| **meta-radxa-dragon** | github.com/CmST0us（fork） | `bf47b24`（scarthgap 最新） | 根（板级 overlay） |

## 子 layer 的处理

只有这三个仓库在 kas 里显式列了 `layers:`，其余仓库根目录本身就是单个 layer：
- `poky` → `meta` + `meta-poky`
- `meta-openembedded` → 仅启用上表 7 个子 layer
- `meta-security` → 根（`.`）+ `meta-tpm`

## meta-radxa-dragon（板级 overlay）

当前为**远端锁定模式**（commit `bf47b24`，即远端 scarthgap HEAD / 分支最新），详见
[versioning](../topics/versioning.md)。它提供：
- machine 配置 `qcs6490-radxa-dragon-q6a`（见 [machine 页](machine-qcs6490-radxa-dragon-q6a.md)）；
- 自定义内核 `linux-qcom-custom`（radxa kernel fork）；
- WiFi/BT 固件配方 `wifibt-firmware`（见 [driver 页](driver-wifi-bt-aic8800d80.md)）；
- fastrpc、linux-firmware、镜像配方等的板级定制；
- gflags 分支改名修复 bbappend（`dynamic-layers/openembedded-layer/.../gflags_2.2.2.bbappend`，
  见 [构建故障](../topics/build-and-dev-workflow.md#常见构建故障)）。

远端：`git@github.com:CmST0us/meta-radxa-dragon.git`（fork 自 `radxa/meta-radxa-dragon`）。

## 相关
- [kas-configuration](../topics/kas-configuration.md) — 这些条目在 yml 里的写法
- [versioning](../topics/versioning.md) — commit 锁定与本地/远端切换
