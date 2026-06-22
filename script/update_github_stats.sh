#!/usr/bin/env bash
#===============================================================================
# update_github_stats.sh — 从 GitHub API 获取 star 与 commit 总数，
# 更新 ../template/CV.tex 中的 \ghstats{stars}{commits}。
#
# 用法：./update_github_stats.sh [github-username]
#   不传用户名时，脚本自动从 CV.tex 的 \ghlink 命令中提取。
#===============================================================================
set -euo pipefail

cd "$(dirname "$0")"

# ---- 常量 ----------------------------------------------------------------
TEX_FILE="../template/CV.tex"

# ---- 工具函数 ------------------------------------------------------------

# 检查命令是否存在，不存在则报错退出
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command '$1'" >&2
    exit 1
  fi
}

# 将大数字转为人类可读的短格式：1200 → 1.2k，1500000 → 1.5m
short_count() {
  local n="$1"
  if (( n >= 1000000 )); then
    local v
    v=$(awk -v n="$n" 'BEGIN { printf "%.1f", n/1000000 }')
    echo "${v%.0}m"
  elif (( n >= 1000 )); then
    local v
    v=$(awk -v n="$n" 'BEGIN { printf "%.1f", n/1000 }')
    echo "${v%.0}k"
  else
    echo "$n"
  fi
}

# ---- 环境检查 ------------------------------------------------------------
require_cmd curl
require_cmd jq
require_cmd perl

if [[ ! -f "$TEX_FILE" ]]; then
  echo "Error: '$TEX_FILE' not found" >&2
  exit 1
fi

# ---- 解析用户名 ----------------------------------------------------------
# 优先使用命令行参数，否则从 tex 文件中自动检测
if [[ -z "${1:-}" ]]; then
  USERNAME=$(perl -ne 'print $1 if /\\ghlink\{https:\/\/github\.com\/([^}]+)\}/' "$TEX_FILE")
  if [[ -z "$USERNAME" ]]; then
    echo "Error: could not detect GitHub username from '$TEX_FILE'. Please pass it as an argument." >&2
    exit 1
  fi
  echo "Detected GitHub username from tex file: @$USERNAME"
else
  USERNAME="$1"
fi

# ---- [1/3] 并行获取 stars 和 commits -------------------------------------
echo "[1/3] Fetching GitHub stats for @$USERNAME ..."

stars_file=$(mktemp)
commits_file=$(mktemp)

# 子进程：分页拉取所有仓库的 star 总数（最多 1000 个仓库）
(
  stars=0 page=1
  while true; do
    resp=$(curl -fsSL "https://api.github.com/search/repositories?q=user:${USERNAME}&per_page=100&page=${page}")
    count=$(echo "$resp" | jq '[.items[].stargazers_count] | add // 0')
    stars=$((stars + count))
    total=$(echo "$resp" | jq '.total_count // 0')
    if [ "$((page * 100))" -ge "$total" ]; then break; fi
    page=$((page + 1))
  done
  echo "$stars" > "$stars_file"
) &

# 子进程：获取 commit 总数（只读 total_count，per_page=1 最小化响应）
(
  curl -fsSL "https://api.github.com/search/commits?q=author:${USERNAME}&per_page=1" \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    | jq '.total_count // 0' > "$commits_file"
) &

# 等待期间显示旋转动画
spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
i=0
while kill -0 $! 2>/dev/null; do
  printf "\r  %s fetching ..." "${spinner:i++%${#spinner}:1}"
  sleep 0.1
done
wait
printf "\r\033[K"  # 清除 spinner 行

stars=$(cat "$stars_file")
commits=$(cat "$commits_file")
rm -f "$stars_file" "$commits_file"

# ---- 校验结果 ------------------------------------------------------------
if ! [[ "$stars" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to parse stars count" >&2
  exit 1
fi

if ! [[ "$commits" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to parse commit count" >&2
  exit 1
fi

stars_fmt=$(short_count "$stars")
commits_fmt=$(short_count "$commits")

echo "  stars=$stars_fmt, commits=$commits_fmt"

# ---- [2/3] 更新 tex 文件 -------------------------------------------------
echo "[2/3] Updating \\ghstats in $TEX_FILE ..."

tmp_file=$(mktemp)
perl -0777 -pe "s/\\\\ghstats\{[^}]*\}\{[^}]*\}/\\\\ghstats\{$stars_fmt\}\{$commits_fmt\}/g" "$TEX_FILE" > "$tmp_file"

if ! grep -q '\\ghstats{' "$tmp_file"; then
  rm -f "$tmp_file"
  echo "Error: failed to update ghstats in '$TEX_FILE'" >&2
  exit 1
fi

if cmp -s "$TEX_FILE" "$tmp_file"; then
  rm -f "$tmp_file"
  echo "Stats unchanged. No file rewrite needed."
else
  mv "$tmp_file" "$TEX_FILE"
  echo "Stats updated in '$TEX_FILE'."
fi

# ---- [3/3] 完成 ----------------------------------------------------------
echo "[3/3] Done."
