# 版本化策略

_最后更新：2026-06-03_

## 原则

- **本仓库（kas 配置）= 事实来源**，类比原来的 repo manifest 仓库。layer 源码不入库。
- layer 版本用 `branch` + `commit` 双写锁定（可复现），等价于 manifest 的 `revision=<sha>`。
- 发布点用本仓库的 **git tag** 标记。

## 三种锁定粒度

| 写法 | 可复现 | 场景 |
|---|---|---|
| 仅 `branch` | 否 | 跟最新开发 |
| `branch` + `commit`（**当前用法**） | 是 | 发布 / CI |
| `tag` | 是 | 上游有 tag 时 |

## 基线决策：维持 QLI.1.5-Ver.1.1（不 bump 到 scarthgap 尖端）

2026-06-04：曾检查发现 11 个远端 layer 中 10 个落后于各自 `scarthgap` HEAD，并试着 bump，
但**已撤回**。决定继续锁定 QLI.1.5-Ver.1.1 对应的 commit——Qualcomm BSP 层与 meta-radxa-dragon
的内核（`kernel.qclinux.1.0.r1-rel`）都对齐该发布点，贸然跟到 scarthgap 尖端的兼容性无保障。
升级基线应整体迁移到新的 QLI 发布，而非逐个 bump。

## lockfile 模式（推荐演进方向）

```bash
kas dump --lock --update kas-radxa-q6a.yml > kas-radxa-q6a.lock.yml
```
主 yml 写 branch 保持可读，lock 文件冻结实际 commit 并提交进 git；升级时重跑 `--update`，
diff 即知哪些 layer 变了。目前尚未启用该模式（仍直接在主 yml 里写 commit）。

## 本地 ↔ 远端切换（meta-radxa-dragon）

**当前为远端锁定模式**（2026-06-04 调试完成后回切）：
```yaml
meta-radxa-dragon:
  url: https://github.com/CmST0us/meta-radxa-dragon.git
  branch: scarthgap
  commit: bf47b24bdb3f30b20c5152fe46638aef6236d891   # 含 aic8800 固件 + gflags 修复
  path: layers/meta-radxa-dragon
```
锁定的 `bf47b24` 即远端 `scarthgap` 的 HEAD，已包含本地开发期的两笔提交
（`b82b968` 装 AIC8800D80 固件、`bf47b24` gflags master→main）。

**需要再次本地调试时**：注释上面 `url/branch/commit/path` 4 行，改用
```yaml
meta-radxa-dragon:
  path: ../meta-radxa-dragon       # 无 url，kas 不接管，改动即时生效
```
调试稳定后回切远端：
1. 在 `../meta-radxa-dragon` 把本地改动 `git push origin scarthgap`。
2. 编辑 `kas-radxa-q6a.yml`：恢复 `url/branch/commit/path`，把 `commit:` 更新为最新 HEAD。
3. `kas dump` 确认解析正常；向 [log](../log.md) 记一条 `change`。

> 否则锁定的 commit 不包含本地改动，远端构建会缺这部分。

## 相关
- [kas-configuration](kas-configuration.md)
- [layers](../components/layers.md)
