# 构建与开发工作流

_最后更新：2026-06-03_

## 前置

```bash
pip install kas          # 或 pipx install kas
```

始终**在本仓库根目录**运行 kas（路径与缓存均相对仓库根解析）。

## 常用命令

```bash
kas dump  kas-radxa-q6a.yml      # 打印解析后的完整配置（不构建），先检查
kas checkout kas-radxa-q6a.yml   # 只检出 layer，不构建
kas build kas-radxa-q6a.yml      # 检出 + 构建 target (qcom-multimedia-image)
kas shell kas-radxa-q6a.yml      # 进入配好的 bitbake 环境，手动 bitbake
```

## 目录布局（运行后）

| 路径 | 内容 | 是否纳入 git |
|---|---|---|
| `layers/` | kas 检出的全部远端 layer（含 meta-radxa-dragon） | 否（.gitignore） |
| `build/` | bitbake 构建目录（默认 `$KAS_WORK_DIR/build`） | 否 |
| `downloads/`, `sstate-cache/` | 源码与共享状态缓存 | 否 |

环境变量：`KAS_WORK_DIR`（工作根，默认运行目录）、`KAS_BUILD_DIR`（构建目录）。
源码缓存默认落在工程内 `downloads/`（见 [kas-configuration](kas-configuration.md) 的 `site` 段）。
按[路径规则](../../CLAUDE.md)，不引用工程外的缓存目录。

## 本地开发 meta-radxa-dragon

当前 `meta-radxa-dragon` 为**远端锁定模式**（commit `bf47b24`，由 kas 检出到 `layers/`）。
需要调试板级配置、驱动、固件（如 [aic8800](../components/driver-wifi-bt-aic8800d80.md)）时，
可临时把它切回同级本地副本 `../meta-radxa-dragon`（改动即时生效、无需 push），
切换与回切步骤见 [versioning](versioning.md)。

## 验证某物是否进镜像

```bash
kas shell kas-radxa-q6a.yml -c "bitbake -g qcom-multimedia-image && grep <pkg> pn-depends.dot"
```

## CI 构建（GitHub Actions）

`.github/workflows/build.yml` 用 kas 在 GitHub 托管 runner 上构建镜像：

- **触发**：手动 `workflow_dispatch`（避免每次 push 跑数小时构建）。输入 `target`
  可选 `qcom-multimedia-image`（默认）/`qcom-console-image`/`qcom-minimal-image`，
  `upload_images` 控制是否上传产物。
- **runner**：`ubuntu-24.04`，`timeout-minutes: 350`（GitHub 单 job 上限 6 小时）。
- **磁盘**：先删除 dotnet/android/CodeQL/boost 等预装大件腾出 ~65GB；配合 yml 里的
  `INHERIT += "rm_work"`（编译完即删 workdir）控制峰值，全量镜像通常能装下。
- **步骤**：装 Yocto host 依赖 + 生成 `en_US.UTF-8` locale → `pip --user` 装 kas →
  `kas dump` 健康检查 → `kas build --target <input>` → 上传
  `build/*/deploy/images/qcs6490-radxa-dragon-q6a/**` 为 artifact（保留 7 天）。
- runner 用户为非 root（`runner`），bitbake 的 "不要以 root 运行" 检查自然通过。
- Ubuntu 24.04 默认用 AppArmor 限制非特权 user namespace，bitbake 需要它，故构建前先
  `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`，否则报
  "User namespaces are not usable by BitBake"。

> 已知风险：sstate/downloads 未做跨 run 缓存（GitHub Actions 缓存上限 10GB，远小于
> Yocto 缓存体量），故每次都是冷构建、较慢。需要加速可自建 sstate-mirror / downloads 镜像。

## 常见构建故障

### gflags do_unpack：`No up to date source ... shallow clone not enabled`
- 现象：`gflags-2.2.2` 的 `do_unpack` 失败，提示缺 `master`。
- 根因：**上游 gflags 已把默认分支 `master` 改名为 `main`**，而 meta-oe(scarthgap) 的 recipe
  仍写 `branch=master`。全新检出的 git 镜像只有 `main`、无 `master`，unpack 的
  `git branch --contains <SRCREV> --list master` 返空。锁定的 SRCREV 其实是 `main` 的祖先。
- **修复（已内置）**：meta-radxa-dragon 的 bbappend
  `dynamic-layers/openembedded-layer/recipes-support/gflags/gflags_2.2.2.bbappend`
  把 SRC_URI 改为 `branch=main`（SRCREV 不变）。上游 meta-oe 修正后可删。
- 不建议用复用旧 downloads 的方式绕过——那只是掩盖问题，且不可复现。
- 见 log `[2026-06-04] change`。

## 相关
- [kas-configuration](kas-configuration.md)
- [versioning](versioning.md)
- [distro-and-images](distro-and-images.md)
