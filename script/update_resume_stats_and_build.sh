#!/usr/bin/env bash
# 运行：./update_resume_stats_and_build.sh [github-username] [tex-file]
set -euo pipefail

cd "$(dirname "$0")"

MODE="full"
if [[ "${1:-}" == "--update-only" ]]; then
  MODE="update-only"
  shift
elif [[ "${1:-}" == "--build-only" ]]; then
  MODE="build-only"
  shift
fi

USERNAME="${1:-your-username}"
TEX_FILE="${2:-../cv/CV.tex}"

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
if [[ "$MODE" != "update-only" ]]; then
  require_cmd xelatex
fi

if [[ ! -f "$TEX_FILE" ]]; then
  echo "Error: '$TEX_FILE' not found" >&2
  exit 1
fi

TEX_DIR=$(dirname "$TEX_FILE")

if [[ "$MODE" != "build-only" ]]; then
  echo "[1/4] Fetching GitHub stars for @$USERNAME ..."
  stars=$(curl -fsSL "https://api.github.com/search/repositories?q=user:${USERNAME}&per_page=100" \
    | jq '[.items[].stargazers_count] | add // 0')

  if ! [[ "$stars" =~ ^[0-9]+$ ]]; then
    echo "Error: failed to parse stars count" >&2
    exit 1
  fi

  echo "[2/4] Fetching GitHub commits for @$USERNAME ..."
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

  echo "[3/4] Updating LaTeX stats: stars=$stars_fmt, commits=$commits_fmt"
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

  if [[ "$MODE" == "update-only" ]]; then
    echo "Done. Updated $TEX_FILE"
    exit 0
  fi
fi

echo "[4/5] Building full PDF (CV.pdf) ..."
full_jobname="CV"
xelatex -interaction=nonstopmode -halt-on-error -jobname="$full_jobname" -output-directory="$TEX_DIR" "$TEX_FILE" >/dev/null
xelatex -interaction=nonstopmode -halt-on-error -jobname="$full_jobname" -output-directory="$TEX_DIR" "$TEX_FILE" >/dev/null

echo "[5/5] Building public (anonymized) PDF (resume.pdf) ..."
public_jobname="resume"
xelatex -interaction=nonstopmode -halt-on-error -jobname="$public_jobname" -output-directory="$TEX_DIR" "\def\PUBLICRESUME{1}\input{$TEX_FILE}" >/dev/null
xelatex -interaction=nonstopmode -halt-on-error -jobname="$public_jobname" -output-directory="$TEX_DIR" "\def\PUBLICRESUME{1}\input{$TEX_FILE}" >/dev/null

# xelatex 会生成编译辅助文件，构建后统一清理，仅保留 PDF。
rm -f \
  "${TEX_DIR}/${full_jobname}.aux" "${TEX_DIR}/${full_jobname}.log" "${TEX_DIR}/${full_jobname}.out" "${TEX_DIR}/${full_jobname}.synctex.gz" \
  "${TEX_DIR}/${public_jobname}.aux" "${TEX_DIR}/${public_jobname}.log" "${TEX_DIR}/${public_jobname}.out" "${TEX_DIR}/${public_jobname}.synctex.gz"

echo "Done. Updated $TEX_FILE and generated:"
echo "  - ${TEX_DIR}/${full_jobname}.pdf"
echo "  - ${TEX_DIR}/${public_jobname}.pdf"
