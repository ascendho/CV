#!/usr/bin/env bash
# 用法：./update_github_stats.sh [github-username]
# 从 GitHub API 获取 star 和 commit 总数，更新 ../template/CV.tex 中的 \ghstats{}{}。
# 如果不指定用户名，脚本会自动从 CV.tex 中的 \ghlink 命令提取。
set -euo pipefail

cd "$(dirname "$0")"

TEX_FILE="../template/CV.tex"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command '$1'" >&2
    exit 1
  fi
}

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

require_cmd curl
require_cmd jq
require_cmd perl

if [[ ! -f "$TEX_FILE" ]]; then
  echo "Error: '$TEX_FILE' not found" >&2
  exit 1
fi

# 如果没有传用户名，从 tex 文件中自动提取
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

echo "[1/3] Fetching GitHub stars for @$USERNAME ..."
stars=$(curl -fsSL "https://api.github.com/search/repositories?q=user:${USERNAME}&per_page=100" \
  | jq '[.items[].stargazers_count] | add // 0')

if ! [[ "$stars" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to parse stars count" >&2
  exit 1
fi

echo "[2/3] Fetching GitHub commits for @$USERNAME ..."
commits=$(curl -fsSL "https://api.github.com/search/commits?q=author:${USERNAME}&per_page=1" \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  | jq '.total_count // 0')

if ! [[ "$commits" =~ ^[0-9]+$ ]]; then
  echo "Error: failed to parse commit count" >&2
  exit 1
fi

stars_fmt=$(short_count "$stars")
commits_fmt=$(short_count "$commits")

echo "[3/3] Updating LaTeX stats: stars=$stars_fmt, commits=$commits_fmt"
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

echo "Done."
