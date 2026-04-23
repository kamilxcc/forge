#!/usr/bin/env bash
# post-tool-use.sh — Claude Code PostToolUse Hook
#
# 作用：每次 Write 或 Edit 工具执行后，把修改的文件路径追加到
#       <project-root>/.forge-kb/.state/modified-files.txt
#
# 挂载方式（在目标项目的 .claude/settings.json 中配置）：
#   {
#     "hooks": {
#       "PostToolUse": [
#         {
#           "matcher": "Write|Edit",
#           "hooks": [
#             {
#               "type": "command",
#               "command": "bash /path/to/forge-plugin/hooks/post-tool-use.sh"
#             }
#           ]
#         }
#       ]
#     }
#   }
#
# 输入：Claude Code 通过 stdin 传入 JSON，格式示例：
#   {
#     "tool_name": "Write",
#     "tool_input": { "file_path": "/absolute/path/to/file.kt" }
#   }
#
# 容错：任何步骤失败都静默退出 0（fail-open）

set -uo pipefail

# 读取 stdin
INPUT="$(cat)"

# 提取 file_path（优先用 jq，降级用 grep）
if command -v jq &>/dev/null; then
  FILE_PATH="$(echo "${INPUT}" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  # 降级：从 JSON 字符串中 grep file_path
  FILE_PATH="$(echo "${INPUT}" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || true)"
fi

# 无法提取路径时静默退出
if [[ -z "${FILE_PATH}" ]]; then
  exit 0
fi

# 从文件路径向上找 .forge-kb（最多往上 8 层）
SEARCH_DIR="$(dirname "${FILE_PATH}")"
KB_STATE=""
for _ in 1 2 3 4 5 6 7 8; do
  if [[ -d "${SEARCH_DIR}/.forge-kb/.state" ]]; then
    KB_STATE="${SEARCH_DIR}/.forge-kb/.state"
    break
  fi
  PARENT="$(dirname "${SEARCH_DIR}")"
  if [[ "${PARENT}" == "${SEARCH_DIR}" ]]; then
    break  # 到达根目录
  fi
  SEARCH_DIR="${PARENT}"
done

# 找不到 .forge-kb/.state 时静默退出（没有初始化知识库的项目不记录）
if [[ -z "${KB_STATE}" ]]; then
  exit 0
fi

MODIFIED_FILE="${KB_STATE}/modified-files.txt"

# 确保文件存在
touch "${MODIFIED_FILE}" 2>/dev/null || exit 0

# 避免重复记录同一个文件
if ! grep -qxF "${FILE_PATH}" "${MODIFIED_FILE}" 2>/dev/null; then
  echo "${FILE_PATH}" >> "${MODIFIED_FILE}" 2>/dev/null || true
fi

exit 0
