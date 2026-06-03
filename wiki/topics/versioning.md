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

## lockfile 模式（推荐演进方向）

```bash
kas dump --lock --update kas-radxa-q6a.yml > kas-radxa-q6a.lock.yml
```
主 yml 写 branch 保持可读，lock 文件冻结实际 commit 并提交进 git；升级时重跑 `--update`，
diff 即知哪些 layer 变了。目前尚未启用该模式（仍直接在主 yml 里写 commit）。

## 本地 ↔ 远端切换（meta-radxa-dragon）

**当前为本地开发模式**：
```yaml
meta-radxa-dragon:
  path: ../meta-radxa-dragon       # 无 url，kas 不接管，改动即时生效
  # url: https://github.com/CmST0us/meta-radxa-dragon.git
  # branch: scarthgap
  # commit: c898e252...
  # path: layers/meta-radxa-dragon
```

**回切远端流程**（调试稳定后）：
1. 在 `../meta-radxa-dragon` 把本地改动 `git push origin scarthgap`
   （注意：固件改动 commit `b82b968` 目前**仅本地**，未 push）。
2. 编辑 `kas-radxa-q6a.yml`：删除 `path: ../meta-radxa-dragon`，取消下面 4 行注释，
   并把 `commit:` 更新为 push 后的最新 HEAD。
3. `kas dump` 确认解析正常；向 [log](../log.md) 记一条 `change`。

> 否则锁定的 commit 不包含本地改动，远端构建会缺这部分。

## 相关
- [kas-configuration](kas-configuration.md)
- [layers](../components/layers.md)
