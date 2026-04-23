#!/usr/bin/env bash
# kb-load.sh — 从目标项目的 .forge-kb/ 加载知识库上下文，输出到 stdout
#
# 用法:
#   kb-load.sh --tier always
#   kb-load.sh --tier task --modules chat,feed --keywords "tab,TabHost"
#   kb-load.sh --kb-path /path/to/.forge-kb --tier task
#
# 参数:
#   --tier always|task   加载层级（必填）
#   --modules <name,...> 按逗号分隔的模块名（tier=task 时可选）
#   --keywords <kw,...>  按逗号分隔的关键词，用于匹配 experience/rules（tier=task 时可选）
#   --kb-path <dir>      .forge-kb 路径（默认：当前目录下的 .forge-kb）
#
# 退出码:
#   0 成功（即使部分文件不存在，也会输出能找到的内容）
#   1 --tier 参数缺失或不合法
#   2 .forge-kb 目录不存在

set -euo pipefail

TIER=""
MODULES=""
KEYWORDS=""
KB_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --modules)
      MODULES="$2"
      shift 2
      ;;
    --keywords)
      KEYWORDS="$2"
      shift 2
      ;;
    --kb-path)
      KB_PATH="$2"
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

if [[ -z "${TIER}" ]]; then
  echo "ERROR: --tier 必填（always 或 task）" >&2
  exit 1
fi

if [[ "${TIER}" != "always" && "${TIER}" != "task" ]]; then
  echo "ERROR: --tier 必须是 always 或 task，得到: ${TIER}" >&2
  exit 1
fi

# 确定 KB 路径
if [[ -z "${KB_PATH}" ]]; then
  KB_PATH="$(pwd)/.forge-kb"
fi

if [[ ! -d "${KB_PATH}" ]]; then
  echo "⚠️  未找到知识库: ${KB_PATH}" >&2
  echo "   运行 /init-kb 初始化，或使用 --kb-path 指定路径。" >&2
  exit 2
fi

# ──────────────────────────────────────────────────────────────
# 辅助函数
# ──────────────────────────────────────────────────────────────

emit_section() {
  local title="$1"
  local file="$2"
  if [[ -f "${file}" ]]; then
    echo ""
    echo "<!-- forge-kb: ${title} -->"
    echo '```yaml'
    cat "${file}"
    echo '```'
    echo ""
  fi
}

emit_md_section() {
  local title="$1"
  local file="$2"
  if [[ -f "${file}" ]]; then
    echo ""
    echo "<!-- forge-kb: ${title} -->"
    cat "${file}"
    echo ""
  fi
}

# ──────────────────────────────────────────────────────────────
# Always-On 层：project.yaml + glossary.yaml
# ──────────────────────────────────────────────────────────────

echo "<!-- forge-kb-start tier=${TIER} -->"

emit_section "project" "${KB_PATH}/meta/project.yaml"
emit_section "glossary" "${KB_PATH}/meta/glossary.yaml"

if [[ "${TIER}" == "always" ]]; then
  echo "<!-- forge-kb-end -->"
  exit 0
fi

# ──────────────────────────────────────────────────────────────
# Task-Scoped 层：module-map + 指定模块 index.md + 关键词匹配 rules
# ──────────────────────────────────────────────────────────────

emit_section "module-map" "${KB_PATH}/meta/module-map.yaml"

# 加载模块 index.md
if [[ -n "${MODULES}" ]]; then
  IFS=',' read -ra MODULE_LIST <<< "${MODULES}"
  for mod in "${MODULE_LIST[@]}"; do
    mod="$(echo "${mod}" | tr -d '[:space:]')"
    idx="${KB_PATH}/modules/${mod}/index.md"
    emit_md_section "module:${mod}" "${idx}"
  done
fi

# 关键词匹配 experience/rules/*.yaml
if [[ -n "${KEYWORDS}" ]]; then
  RULES_DIR="${KB_PATH}/experience/rules"
  if [[ -d "${RULES_DIR}" ]]; then
    IFS=',' read -ra KW_LIST <<< "${KEYWORDS}"

    # 构建 grep 匹配模式（任一关键词匹配即包含该文件）
    GREP_PATTERN=""
    for kw in "${KW_LIST[@]}"; do
      kw="$(echo "${kw}" | tr -d '[:space:]')"
      if [[ -n "${GREP_PATTERN}" ]]; then
        GREP_PATTERN="${GREP_PATTERN}|${kw}"
      else
        GREP_PATTERN="${kw}"
      fi
    done

    if [[ -n "${GREP_PATTERN}" ]]; then
      while IFS= read -r -d '' rule_file; do
        # 检查 keywords: 字段是否匹配（大小写不敏感）
        if grep -qiE "keywords:.*?(${GREP_PATTERN})" "${rule_file}" 2>/dev/null || \
           grep -qiE "- (${GREP_PATTERN})" "${rule_file}" 2>/dev/null; then
          fname="$(basename "${rule_file}")"
          echo ""
          echo "<!-- forge-kb: rules:${fname} -->"
          echo '```yaml'
          cat "${rule_file}"
          echo '```'
          echo ""
        fi
      done < <(find "${RULES_DIR}" -name "*.yaml" -print0 2>/dev/null)
    fi
  fi
fi

echo "<!-- forge-kb-end -->"
