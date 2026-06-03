# kas 配置详解

_最后更新：2026-06-03_

`kas-radxa-q6a.yml` 的结构说明。真值以该文件为准。

## 顶层字段

| 字段 | 值 | 说明 |
|---|---|---|
| `header.version` | `14` | kas **文件格式**版本，跟随工具能力，不是项目版本 |
| `build_system` | `openembedded` | 用 OE/poky 的 `oe-init-build-env` |
| `machine` | `qcs6490-radxa-dragon-q6a` | 写入 `local.conf` 的 `MACHINE` |
| `distro` | `qcom-wayland` | 写入 `local.conf` 的 `DISTRO` |
| `target` | `qcom-multimedia-image` | `bitbake` 目标，见 [distro-and-images](distro-and-images.md) |

## repos

每个 layer 仓库一个条目。两种模式：

**远端托管**（kas 负责 clone + checkout）：
```yaml
poky:
  url: https://git.yoctoproject.org/poky
  branch: scarthgap
  commit: 0ce88bc...
  path: layers/poky          # 相对 KAS_WORK_DIR
  layers:                    # 仓库非单一 layer 时显式列出子 layer
    meta:
    meta-poky:
```

**本地开发**（无 `url`，kas 不接管，直接用现有目录）：
```yaml
meta-radxa-dragon:
  path: ../meta-radxa-dragon
```
本地模式下不能写 `commit`/`branch`。详见 [versioning](versioning.md)。

完整清单见 [layers](../components/layers.md)。

### layers 子键规则
- 不写 `layers:` → 仓库根作为单个 layer（前提是根有 `conf/layer.conf`）。
- 写 `layers:` → 只添加列出的子路径；根用 `.` 表示（如 `meta-security` 的 `.` + `meta-tpm`）。

## local_conf_header

把内容合并进 `local.conf`，替代原 `set_bb_env.sh` 生成的 local/auto/site.conf。分三块：

- `distro-defaults`：来自 `meta-qcom-distro/conf/local.conf`（并行度、`BBMULTICONFIG = qcom-guestvm`、
  屏蔽 aktualizr、`PATCHRESOLVE=noop` 等）。
- `qcom-bsp`：来自原 `auto.conf`（`QCOM_SELECTED_BSP=custom`、`INHERIT += rm_work`、
  `DEBUG_BUILD/PERFORMANCE_BUILD=0`、`SDKMACHINE`）。`DISTRO`/`MACHINE` 由 kas 写入，不在此重复。
- `site`：`DL_DIR`/`SSTATE_DIR`（`?=`，默认本仓库下，可用环境变量覆盖）+ codelinaro `MIRRORS`。

## 相关
- [build-and-dev-workflow](build-and-dev-workflow.md)
- [versioning](versioning.md)
- [layers](../components/layers.md)
