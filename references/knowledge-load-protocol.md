# knowledge-load-protocol — 知识库加载协议

本片段被所有 Agent prompt 在「执行流程」开头引用。
它描述了三级知识库加载的标准步骤。

---

## 知识库加载步骤（每次任务开始时执行）

**第 1 步：定位知识库**

1a. 先确认当前 `<project-name>`（从 `work/` 下的目录名或任务上下文获取）。

1b. 读取状态文件：

```
<plugin-root>/work/<project-name>/.kb-path
```

该文件由 `/init-kb` 写入，内容为知识库的绝对路径（如 `/Users/xxx/code/my-project/.forge-kb`）。

1c. 若状态文件不存在，则 fallback 到检查当前目录是否存在 `.forge-kb/`：

```
IF .kb-path 文件不存在 AND .forge-kb/ 不存在:
  输出警告：
    ⚠️  未找到知识库（.kb-path 未记录，.forge-kb/ 也不存在）。
        运行 /init-kb 可初始化知识库以获得更好的 AI 支持。
        当前将在无知识库模式下继续任务。
  继续执行任务（不中断，不报错）
ELSE:
  继续第 2 步，使用找到的知识库路径
```

**第 2 步：Always-On 层（始终加载）**

调用：
```bash
bash <plugin-root>/scripts/kb-load.sh \
  --tier always \
  --kb-path <kb-root>
```

将输出注入当前上下文（直接 Read 两个文件等价）。

若脚本不可用，手动 Read：
- `<kb-root>/meta/project.yaml`
- `<kb-root>/meta/glossary.yaml`

**第 3 步：Task-Scoped 层（按任务推断后加载）**

3a. 用 module-resolver 推断涉及模块：
- 读 `<kb-root>/meta/module-map.yaml`
- 将任务描述中出现的类名/路径/功能词与 `paths` 字段做模糊匹配
- 找不到匹配时跳过，不报错

3b. 调用：
```bash
bash <plugin-root>/scripts/kb-load.sh \
  --tier task \
  --kb-path <kb-root> \
  --modules "<module1>,<module2>" \
  --keywords "<kw1>,<kw2>"
```

关键词提取规则：从任务描述中抽取名词/类名，最多 5 个，逗号分隔。

**第 4 步：On-Demand 层（执行中按需读取）**

执行过程中遇到需要深入了解的子域时，按需 Read：
- `<kb-root>/modules/<name>/<subdomain>.md`（如 tab-system.md）
- `<kb-root>/experience/cases/<slug>.md`（具体案例）

---

## 加载结果处理

加载到的知识库内容应作为背景知识影响后续决策，具体规则：

1. **glossary.yaml 优先**：当代码命名与产品术语不同时，以 glossary 为准
2. **rules 中 CRITICAL 级别的规则**：在相关操作前主动提示，不可跳过
3. **rules 中 WARN 级别的规则**：在 review 或决策时纳入评估
4. **KB 内容不是 ground truth**：若 KB 内容与代码明显矛盾，以代码为准，并在输出末尾标注「建议更新 KB」

---

## 快捷判断：是否需要加载 task 层？

| 任务类型 | 加载层级 |
|---------|---------|
| /clarify 需求澄清 | always（了解现有功能术语）|
| /plan 新需求 | always + task |
| /implement 执行计划 | always + task |
| /review 代码审查 | always + task |
| /test 写测试 | always + task |
| /onboard 模块了解 | always + task（指定模块）|
| /init-kb 初始化 | 不加载（KB 不存在）|
