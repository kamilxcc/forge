# Feature Selector（-l Flag 交互协议）

调用方已通过 `list-features.sh` 拿到输出，本协议负责展示和交互部分。

---

## 输入

`list-features.sh` 的 stdout，每行格式：

```
<dated-slug> [current]? [has:<doc1>,<doc2>]?
```

## 步骤

1. 解析每行，取最多 4 条（最新在前）构建选项：
   - `label`：`<dated-slug>`（含 `[current]` 的加 ` ← 当前`）
   - `description`：`已有：<docs>`（无文档时显示 `空目录`）
2. 超出 4 条时，调用前先输出：`（共 N 个需求，仅显示最近 4 个。如需更早的需求，请在 Other 中输入 dated-slug。）`
3. 调用 `AskUserQuestion`，`header: 选择需求`，`multiSelect: false`
4. 将选中的 `dated-slug` 记为 `active_slug`
5. 若用户通过 Other 手动输入，验证目录 `work/<project-name>/<input>/` 是否存在；不存在则报错停止：
   ```
   ❌ 未找到需求目录：work/<project-name>/<input>
      请检查 dated-slug 是否正确（格式：YYYY-MM-DD-<slug>）。
   ```

## 输出

`active_slug` — 仅供本次命令使用，**不更新 `.current-feature`**。
