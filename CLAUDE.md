# CLAUDE.md — kas-radxa-dragon

本文件是给 Claude Code 的**仓库说明 + wiki 维护规约**（即 LLM Wiki 模式中的 “schema 层”）。
阅读本文件后，你应当既理解本仓库是什么，也知道每次改动后如何维护 `wiki/`。

---

## 一、本仓库是什么

`kas-radxa-dragon` 是一个 **kas 集成仓库（integration repo）**，用 [kas](https://github.com/siemens/kas)
统一管理 **Radxa Dragon Q6A（QCS6490）** 的 Yocto/OpenEmbedded 构建，取代原先基于 `repo` +
`set_bb_env.sh` 的流程。

- **本仓库只存配置，不存任何 layer 源码**。所有 layer 由 kas 按 `kas-radxa-q6a.yml` 里的
  URL/commit 拉取到本地 `layers/`（已被 `.gitignore` 忽略）。
- 基线：Qualcomm Linux **QLI.1.5-Ver.1.1**（scarthgap），源自 manifest
  `qcom-6.6.90-QLI.1.5-Ver.1.1_qim-product-sdk-2.0.1.xml`。
- 目标机器 `qcs6490-radxa-dragon-q6a`，发行版 `qcom-wayland`，默认镜像 `qcom-multimedia-image`。

仓库文件：

| 文件/目录 | 作用 |
|---|---|
| `kas-radxa-q6a.yml` | 主 kas 配置：12 个 layer、machine/distro/target、`local_conf_header` |
| `.gitignore` | 忽略 `layers/ build/ downloads/ sstate-cache/` 等检出与产物 |
| `CLAUDE.md` | 本文件 |
| `wiki/` | LLM 维护的知识库（见下） |

> 详细内容见 `wiki/overview.md` 及各组件页面。**当 wiki 与本节冲突时，以 wiki 的细节页为准**
> （本节只是入口摘要）。

---

## 二、关键工作约定（先读这条）

> **每次对本仓库有实质改动（改 kas 配置、调整 layer、改 machine/distro、驱动/固件、
> 构建流程、版本基线等），都必须同步更新 `wiki/`。** 这是硬性规则，不是可选项。

“实质改动”包括但不限于：
- 修改 `kas-radxa-q6a.yml`（layer 增删、commit/branch 变更、本地↔远端切换、`local_conf_header`）；
- 改动所引用 layer 的关键配置（如 `meta-radxa-dragon` 的 machine conf、驱动/固件）；
- 升级 Qualcomm Linux / poky 基线；
- 调整构建/调试工作流或版本化策略。

纯笔误修正、注释微调可不更新 wiki。拿不准时——更新。

---

## 三、wiki 结构与约定

`wiki/` 是一个由你（LLM）完整维护的、互相链接的 Markdown 知识库。用户负责提问与决策，
你负责所有的撰写、交叉引用、归档与记账。

```
wiki/
├── index.md          # 内容目录：列出所有页面 + 一句话摘要（页面增删时更新）
├── log.md            # 时间线：append-only，记录每次 change/decision/finding/lint
├── overview.md       # 仓库总览与架构
├── topics/           # 概念页（怎么做、为什么这么做）
│   ├── kas-configuration.md
│   ├── build-and-dev-workflow.md
│   ├── versioning.md
│   └── distro-and-images.md
└── components/       # 实体页（具体的东西）
    ├── layers.md                          # 全部 layer 清单与锁定版本
    ├── machine-qcs6490-radxa-dragon-q6a.md
    └── driver-wifi-bt-aic8800d80.md
```

约定：
- **链接**：页面间用相对 Markdown 链接，如 `[layers](../components/layers.md)`。GitHub 与
  Obsidian 都能渲染。每个页面尽量链接到相关页面，避免孤立页。
- **真值来源**：代码/配置（`kas-radxa-q6a.yml`、各 layer）永远是 source of truth；wiki 是它的
  人类可读说明。**写入 commit hash、版本号、CONFIG 项等事实前，先去对应文件核实**，不要凭记忆。
- **页面头部**可选加一行 `_最后更新：YYYY-MM-DD_`。
- **不要**把检出的 layer 源码内容大段拷进 wiki；wiki 写的是结论、关系、决策与指引。

---

## 四、工作流

### 同步（每次改动后必做）
1. 判断本次改动影响哪些 wiki 页，更新这些页（事实先核实再写）。
2. 若新增/删除了页面，更新 `index.md`。
3. 向 `log.md` **追加**一条记录（见下方格式）。一次改动可能触及多页，但只记一条 log。

### log.md 记录格式
每条以统一前缀开头，便于 `grep "^## \[" wiki/log.md | tail -5` 速览：

```
## [YYYY-MM-DD] <type> | <一句话标题>
- 改了什么、为什么
- 影响的 wiki 页：components/xxx.md, topics/yyy.md
- 相关 commit / 文件
```

`<type>` 取值：`change`（配置/代码变更）、`decision`（设计决策）、`finding`（调查结论）、
`lint`（健康检查）、`ingest`（新增成体系的资料）。

### 查询
回答关于本仓库的问题时：先读 `wiki/index.md` 定位相关页 → 读细页 → 综合作答并给出引用
（页面或文件路径）。**有价值的分析结论应回填进 wiki**（新页或并入已有页），别让它只留在对话里。

### lint（按需）
用户要求时对 wiki 做健康检查：找矛盾、被新事实推翻的旧说法、孤立页、缺失交叉引用、
与当前 `kas-radxa-q6a.yml` 不一致的 commit/版本。修正并在 `log.md` 记一条 `lint`。

---

## 五、当前状态备忘（易变，细节以 wiki 为准）

- `meta-radxa-dragon` 目前为**远端模式**：`kas-radxa-q6a.yml` 中用 `url` + `branch: scarthgap`
  + `commit` 锁定，commit 已更新为 scarthgap 分支最新 `bf47b24`，kas 检出到 `layers/meta-radxa-dragon`。
- 需要调试驱动/固件时，可临时改回本地模式（`path: ../meta-radxa-dragon`，无 `url`），改动即时生效；
  此时请在本仓库目录（`kas-radxa-dragon/`）下运行 kas，使 `../meta-radxa-dragon` 正确解析。

---

## 六、给开发者的常用命令

```bash
pip install kas                                   # 或 pipx install kas
cd /home/eki/Project/carbon/kas-radxa-dragon
kas dump  kas-radxa-q6a.yml                        # 先看解析结果
kas build kas-radxa-q6a.yml                        # 检出 layer 并构建
kas shell kas-radxa-q6a.yml                        # 进入 bitbake 环境

# 复用旧项目已下载的源码缓存，避免重新下载:
DL_DIR=/home/eki/Project/carbon/qualcomm/radxa-q6a-qcom-linux/downloads \
    kas build kas-radxa-q6a.yml
```
