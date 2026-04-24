#!/usr/bin/env bash
# validate-task.sh — forge-plugin task.md 格式校验
#
# 用法：
#   bash validate-task.sh <task.md 的绝对路径>
#
# 退出码：
#   0  所有检查通过
#   1  发现一条或多条违规（详情输出到 stdout）
#
# 校验规则：
#   R1  修改现有文件的步骤，`文件` 字段必须是绝对路径（以 / 开头）
#   R2  修改现有文件的步骤，`文件` 字段必须包含行号范围（path:N-M 格式）
#   R3  步骤内容不得出现委托搜索语言（"executor grep/find/确认 X"等）
#
# 新建文件的步骤（文件字段或做什么字段含 "新建"）豁免 R2 行号范围检查。
#
# 性能说明：
#   全部字符串匹配使用 bash 内置 [[ =~ ]] 和参数展开，零 subprocess fork，
#   百行 task.md 通常在 50ms 内完成。

set -euo pipefail

TASK_FILE="${1:-}"
if [[ -z "$TASK_FILE" ]]; then
  echo "用法：$0 <task.md 的绝对路径>" >&2
  exit 1
fi
if [[ ! -f "$TASK_FILE" ]]; then
  echo "❌ 文件不存在：$TASK_FILE" >&2
  exit 1
fi

errors=()

# ──────────────────────────────────────────────────────────
# 单次遍历：同时处理 R1/R2（按步骤）和 R3（全文）
# ──────────────────────────────────────────────────────────

step_no=0
step_file_field=""
step_is_new=0
lineno=0

# R3 合并为单个 ERE pattern，用 [[ =~ ]] 匹配，无 subprocess
R3_PAT='executor.*(grep|find|搜索|确认)|执行前.*(grep|find|搜索)|需要.*executor.*确认|需要.*grep|先.*(grep|find).*确认'

flush_step() {
  [[ -z "$step_file_field" ]] && return

  # 新建文件判断（纯 bash 字符串匹配）
  local is_new=0
  if [[ "$step_file_field" == *新建* || "$step_file_field" == *（新建）* || $step_is_new -eq 1 ]]; then
    is_new=1
  fi

  # 提取路径：去掉反引号、括号注释、行号范围、尾部空格说明
  # 全用参数展开，零 fork
  local p="$step_file_field"
  p="${p//\`/}"                         # 去反引号
  p="${p%%（*}"                          # 去 （新建） 等括号注释
  p="${p%%(*}"                           # 去 (new) 等 ASCII 括号
  p="${p%%:[0-9]*}"                      # 去 :N-M 行号范围（贪心去尾）
  p="${p%% *}"                           # 去尾部空格后的说明
  p="${p#"${p%%[! ]*}"}"                 # ltrim 前导空格

  # R1：绝对路径
  if [[ "$p" != /* ]]; then
    errors+=("R1 [Step $step_no] 文件路径不是绝对路径：$step_file_field")
  fi

  # R2：现有文件必须有 :N-M
  if [[ $is_new -eq 0 ]]; then
    if [[ ! "$step_file_field" =~ :[0-9]+-[0-9]+ ]]; then
      errors+=("R2 [Step $step_no] 修改现有文件但未标注行号范围：$step_file_field")
    fi
  fi
}

while IFS= read -r line; do
  lineno=$((lineno + 1))

  # ── R3 全文扫描（内置正则，零 fork）──
  if [[ "$line" =~ $R3_PAT ]]; then
    errors+=("R3 [行 $lineno] 委托搜索语言：$line")
  fi

  # ── 步骤边界检测 ──
  if [[ "$line" =~ ^[[:space:]]*-\ \[\ \]\ Step\ [0-9]+: || \
        "$line" =~ ^[[:space:]]*-\ \[x\]\ Step\ [0-9]+: ]]; then
    flush_step
    step_no=$((step_no + 1))
    step_file_field=""
    step_is_new=0
    continue
  fi

  [[ $step_no -eq 0 ]] && continue

  # ── 字段解析 ──
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*文件：(.*) ]]; then
    step_file_field="${BASH_REMATCH[1]}"
    # trim 前导空格
    step_file_field="${step_file_field#"${step_file_field%%[! ]*}"}"
    continue
  fi

  # 新建关键词（做什么字段等）
  if [[ "$line" == *新建* || "$line" == *（新建）* ]]; then
    step_is_new=1
  fi

done < "$TASK_FILE"

flush_step  # 处理最后一个步骤

# ──────────────────────────────────────────────────────────
# 输出结果
# ──────────────────────────────────────────────────────────

if [[ ${#errors[@]} -eq 0 ]]; then
  echo "✅ task.md 校验通过（共 $step_no 步）"
  exit 0
else
  echo "❌ task.md 校验失败，发现 ${#errors[@]} 条违规："
  echo ""
  for err in "${errors[@]}"; do
    echo "  • $err"
  done
  echo ""
  echo "修复方法："
  echo "  R1：文件路径改为绝对路径（以 / 开头）"
  echo "  R2：修改现有文件时，文件字段改为 /path/File.kt:起始行-结束行 格式"
  echo "  R3：删除步骤中委托 executor 搜索的语言，改为 ⚠️ 无参考实现 或在 Plan 阶段探索完成"
  exit 1
fi
