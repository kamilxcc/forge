# task.md 模板

```markdown
---
feature: <slug>
dated_slug: <dated-slug>
plan_doc: plan.md
requirement_doc: requirement.md   # 模式 B（轻量路径）时改为 inline
created_at: YYYY-MM-DD
status: draft
estimated_steps: N
recommended_mode: inline|agent
---

# 执行计划：<功能名>

## 步骤列表

- [ ] Step 1: <标题>
  - 文件：`<绝对文件路径>:<起始行>-<结束行>`（修改现有文件时必填行号范围；新建文件写绝对路径即可）
  - 做什么：<具体改动描述；项目特有业务逻辑（schema/路由/IOC 调用）附完整代码片段；标准模式（Fragment 骨架、枚举追加等）只写字段名/方法名>
  - 参考：`<同文件或同模块中的参考实现位置>`（无则标注 ⚠️ 无参考实现）
  - 插入位置：<方法名 + 精确行号>
- [ ] Step 2: <标题>
  - 文件：`<绝对文件路径>:<起始行>-<结束行>`
  - 做什么：<具体改动描述；项目特有业务逻辑附完整代码片段；标准模式只写方法名/字段名>
  - 参考：`<参考实现位置>`
  - 插入位置：<方法名 + 精确行号>
...

## 风险点

- **<风险>**：<简短说明及应对>

## 依赖

- <前置条件或依赖接口>（无则删除）

## 执行建议

模式：**<inline|agent>**
理由：步骤数 = N，<简短说明>
```
