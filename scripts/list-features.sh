#!/usr/bin/env bash
# list-features.sh — 列出指定项目下的所有需求（dated-slug），供 skill 构建选择器
#
# 用法:
#   list-features.sh --project-name <name> --plugin-root <dir>
#
# 参数:
#   --project-name <name>   目标项目名（来自 project.yaml 的 project.name）
#   --plugin-root <dir>     forge-plugin 根目录（默认：当前目录）
#
# 输出（stdout，每行一条）:
#   <dated-slug> [current] [has:<doc1>,<doc2>]
#   例：
#     2026-04-23-add-aiapp-card [current] [has:requirement.md,plan.md,task.md]
#     2026-04-22-add-hot-discussion-card [has:requirement.md,plan.md]
#
# 输出按 dated-slug 降序（最新在前）。
# 若无任何需求目录，退出码为 0，stdout 为空。
#
# 退出码:
#   0 成功（含无需求的情况）
#   1 参数缺失
#   2 work/<project-name>/ 目录不存在

set -euo pipefail

PLUGIN_ROOT=""
PROJECT_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --plugin-root)
      PLUGIN_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: 未知参数 $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${PROJECT_NAME}" ]]; then
  echo "ERROR: --project-name 必填" >&2
  exit 1
fi

if [[ -z "${PLUGIN_ROOT}" ]]; then
  PLUGIN_ROOT="$(pwd)"
fi

WORK_DIR="${PLUGIN_ROOT}/work/${PROJECT_NAME}"

if [[ ! -d "${WORK_DIR}" ]]; then
  echo "ERROR: 需求目录不存在: ${WORK_DIR}" >&2
  exit 2
fi

# 读取当前 feature 指针
CURRENT_SLUG=""
CURRENT_FEATURE_FILE="${WORK_DIR}/.current-feature"
if [[ -f "${CURRENT_FEATURE_FILE}" ]]; then
  CURRENT_SLUG="$(tr -d '[:space:]' < "${CURRENT_FEATURE_FILE}")"
fi

# 扫描所有 YYYY-MM-DD-* 子目录，降序排列
while IFS= read -r slug; do
  # 检查该目录下有哪些标准文档
  docs=()
  for doc in requirement.md plan.md task.md review.md bugfix.md; do
    if [[ -f "${WORK_DIR}/${slug}/${doc}" ]]; then
      docs+=("${doc}")
    fi
  done

  # 构建输出行
  line="${slug}"

  if [[ "${slug}" == "${CURRENT_SLUG}" ]]; then
    line="${line} [current]"
  fi

  if [[ ${#docs[@]} -gt 0 ]]; then
    docs_str="$(IFS=','; echo "${docs[*]}")"
    line="${line} [has:${docs_str}]"
  fi

  echo "${line}"
done < <(
  find "${WORK_DIR}" -mindepth 1 -maxdepth 1 -type d -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*" \
    | while IFS= read -r d; do basename "$d"; done \
    | sort -r
)
