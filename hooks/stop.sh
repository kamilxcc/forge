#!/usr/bin/env bash
# stop.sh — Claude Code Stop Hook
#
# 作用：会话结束时，若本次修改了文件（modified-files.txt 非空），
#       输出一条提示，建议用户运行 /deposit 沉淀经验。
#
# 挂载方式（在目标项目的 .claude/settings.json 中配置）：
#   {
#     "hooks": {
#       "Stop": [
#         {
#           "hooks": [
#             {
#               "type": "command",
#               "command": "bash /path/to/forge-plugin/hooks/stop.sh"
#             }
#           ]
#         }
#       ]
#     }
#   }
#
# 输入：Claude Code 通过 stdin 传入 JSON（Stop Hook 中通常为空或包含会话信息）
# 输出：若有修改文件，向 stdout 输出提示（Claude Code 会将 stdout 展示给用户）
#
# 容错：任何步骤失败都静默退出 0（fail-open）

set -uo pipefail

# 在当前目录及上级目录中寻找 .forge-kb/.state/modified-files.txt
SEARCH_DIR="$(pwd)"
MODIFIED_FILE=""
for _ in 1 2 3 4 5 6 7 8; do
  candidate="${SEARCH_DIR}/.forge-kb/.state/modified-files.txt"
  if [[ -f "${candidate}" ]]; then
    MODIFIED_FILE="${candidate}"
    break
  fi
  PARENT="$(dirname "${SEARCH_DIR}")"
  if [[ "${PARENT}" == "${SEARCH_DIR}" ]]; then
    break
  fi
  SEARCH_DIR="${PARENT}"
done

# 找不到文件，或文件为空，静默退出
if [[ -z "${MODIFIED_FILE}" ]] || [[ ! -s "${MODIFIED_FILE}" ]]; then
  exit 0
fi

# 统计修改文件数
FILE_COUNT="$(grep -c . "${MODIFIED_FILE}" 2>/dev/null || echo 0)"

if [[ "${FILE_COUNT}" -gt 0 ]]; then
  echo ""
  echo "💡 Forge 提示：本次会话修改了 ${FILE_COUNT} 个文件。"
  echo "   运行 /deposit 可将踩坑经验、设计决策沉淀到知识库，帮助下次 AI 更好地理解项目。"
  echo ""
fi

exit 0
