#!/usr/bin/env bash
# init-kb.sh — 在目标项目根目录创建 .forge-kb/ 知识库骨架
#
# 用法:
#   init-kb.sh                   # 在当前目录初始化
#   init-kb.sh --path /some/dir  # 在指定目录初始化
#   init-kb.sh --force           # 已存在时覆盖
#
# 退出码:
#   0 成功
#   1 目标目录已存在 .forge-kb/ 且未加 --force
#   2 找不到模板目录
#   3 其他参数错误

set -euo pipefail

# 脚本自身定位 —— 模板在 ../skills/forge/templates/kb 相对于本脚本（位于仓库根 scripts/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "${SCRIPT_DIR}/../skills/forge/templates/kb" 2>/dev/null && pwd || true)"

if [[ -z "${TEMPLATE_DIR}" || ! -d "${TEMPLATE_DIR}" ]]; then
  echo "ERROR: 找不到模板目录: ${SCRIPT_DIR}/../skills/forge/templates/kb" >&2
  exit 2
fi

TARGET_PATH="$(pwd)"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      TARGET_PATH="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: 未知参数 $1" >&2
      exit 3
      ;;
  esac
done

if [[ ! -d "${TARGET_PATH}" ]]; then
  echo "ERROR: 目标目录不存在: ${TARGET_PATH}" >&2
  exit 3
fi

KB_DIR="${TARGET_PATH}/.forge-kb"

if [[ -d "${KB_DIR}" && "${FORCE}" -eq 0 ]]; then
  echo "ERROR: ${KB_DIR} 已存在。使用 --force 覆盖(会保留 meta/,只补其他目录)。" >&2
  exit 1
fi

mkdir -p \
  "${KB_DIR}/meta" \
  "${KB_DIR}/modules" \
  "${KB_DIR}/experience/rules" \
  "${KB_DIR}/experience/cases" \
  "${KB_DIR}/features" \
  "${KB_DIR}/.state"

# 拷贝 meta 模板(三份 yaml)—— 如果已存在则保留用户内容
for f in project.yaml glossary.yaml module-map.yaml; do
  src="${TEMPLATE_DIR}/${f}"
  dst="${KB_DIR}/meta/${f}"
  if [[ -f "${src}" && ! -f "${dst}" ]]; then
    cp "${src}" "${dst}"
  fi
done

# 拷贝示例(如果模板目录下有,放在 .examples/ 下,避免污染真实内容)
EX_DIR="${KB_DIR}/.examples"
mkdir -p "${EX_DIR}"
if [[ -f "${TEMPLATE_DIR}/modules/example-module.md" ]]; then
  cp "${TEMPLATE_DIR}/modules/example-module.md" "${EX_DIR}/example-module.md"
fi
if [[ -f "${TEMPLATE_DIR}/experience/rules/example-rules.yaml" ]]; then
  cp "${TEMPLATE_DIR}/experience/rules/example-rules.yaml" "${EX_DIR}/example-rules.yaml"
fi
if [[ -f "${TEMPLATE_DIR}/features/example-feature.md" ]]; then
  cp "${TEMPLATE_DIR}/features/example-feature.md" "${EX_DIR}/example-feature.md"
fi

# 写一份顶层 README 说明
cat > "${KB_DIR}/README.md" <<'EOF'
# .forge-kb — Forge 项目知识库

本目录由 Forge 插件的 `/init-kb` 生成。知识库的作用是给 AI Agent 提供
**代码中读不出来的知识**(产品术语映射、跨类协作、隐性约束、历史坑点等)。

## 最小存活集(只要维护这三样,Forge 就能跑)

1. `meta/glossary.yaml` — 产品术语 ↔ 代码命名 映射。**最高价值**,几百
   tokens 干掉 80% AI 幻觉。初版 1-2 小时头脑风暴即可完成。
2. `meta/project.yaml` — 项目元信息(平台、编译命令、架构特色)。<200 tokens。
3. `meta/module-map.yaml` — 模块路径映射,供变更传播使用。

## 按需扩展

- `modules/<name>/index.md` — 某个活跃模块的导航地图(做该模块需求时顺手构建)
- `experience/rules/*.yaml` — Agent 可检索的规则(由 `/deposit` 自动追加)
- `experience/cases/*.md` — 详细案例(人写经验帖,由 `/deposit` 可选追加)
- `features/*.md` — 需求文档(`/plan` 自动生成)

## 自动生成 vs 人工维护

知识库中最危险的状态是两者混在一起。请在文件头部或段落前用:

- `> [!human-maintained]` — 人工维护,Agent 不得覆盖
- `> [!auto-generated] 生成于 YYYY-MM-DD` — 自动生成,可被重建

## 参考

- 设计文档: `/Users/kamilxiao/my-ai-wiki/wiki/topics/design/knowledge-base-strategy.md`
- 插件入口: `skills/forge/SKILL.md`

## 示例

`.examples/` 目录下有三份示例文件,参考它们的结构后再删除。
EOF

# 初始化 .state/ 下空文件(供 Hook 追加)
: > "${KB_DIR}/.state/modified-files.txt"

echo "✅ Forge 知识库已初始化: ${KB_DIR}"
echo ""
echo "下一步(最小存活集):"
echo "  1. 编辑 ${KB_DIR}/meta/project.yaml  — 填入项目元信息"
echo "  2. 编辑 ${KB_DIR}/meta/glossary.yaml — 头脑风暴添加 10-20 条黑话映射"
echo "  3. 编辑 ${KB_DIR}/meta/module-map.yaml — 登记 2-3 个核心模块路径"
echo ""
echo "完成后可运行 /plan <需求> 开始研发。"
