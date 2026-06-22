<#
.SYNOPSIS
  从 GitHub API 获取 star 与 commit 总数，更新 ..\template\CV.tex 中的 \ghstats{stars}{commits}。

.DESCRIPTION
  不传 -Username 时，脚本自动从 CV.tex 的 \ghlink 命令中提取 GitHub 用户名。

.PARAMETER Username
  GitHub 用户名（可选）。不传则自动检测。

.EXAMPLE
  .\update_github_stats.ps1
  .\update_github_stats.ps1 -Username ascendho
#>

param(
  [string]$Username = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# ---- 常量 ----------------------------------------------------------------
$TexFile = "..\template\CV.tex"

# ---- 工具函数 ------------------------------------------------------------

# 检查命令是否存在，不存在则报错退出
function Require-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Error: missing required command '$Name'"
  }
}

# 将大数字转为人类可读的短格式：1200 → 1.2k，1500000 → 1.5m
function Short-Count {
  param([Parameter(Mandatory = $true)][long]$Value)

  if ($Value -ge 1000000) {
    return ("{0:0.#}m" -f ($Value / 1000000.0))
  }
  if ($Value -ge 1000) {
    return ("{0:0.#}k" -f ($Value / 1000.0))
  }
  return [string]$Value
}

# ---- 环境检查 ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $TexFile)) {
  throw "Error: '$TexFile' not found"
}

# ---- 解析用户名 ----------------------------------------------------------
# 优先使用 -Username 参数，否则从 tex 文件中自动检测
if (-not $Username) {
  $content = Get-Content -LiteralPath $TexFile -Raw -Encoding UTF8
  if ($content -match '\\ghlink\{https://github\.com/([^}]+)\}') {
    $Username = $Matches[1]
    Write-Host "Detected GitHub username from tex file: @$Username"
  } else {
    throw "Error: could not detect GitHub username from '$TexFile'. Please pass -Username."
  }
}

# ---- [1/3] 并行获取 stars 和 commits -------------------------------------
Write-Host "[1/3] Fetching GitHub stats for @$Username ..."

# 子任务：分页拉取所有仓库的 star 总数（最多 1000 个仓库）
$starsJob = Start-Job -ScriptBlock {
  param($Username)
  $stars = 0
  $page = 1
  do {
    $resp = Invoke-RestMethod -Uri "https://api.github.com/search/repositories?q=user:$Username&per_page=100&page=$page"
    $count = ($resp.items | Measure-Object -Property stargazers_count -Sum).Sum
    if ($null -eq $count) { $count = 0 }
    $stars += $count
    $total = $resp.total_count
    if ($null -eq $total) { $total = 0 }
    $page++
  } while (($page - 1) * 100 -lt $total)
  $stars
} -ArgumentList $Username

# 子任务：获取 commit 总数（只读 total_count，per_page=1 最小化响应）
$commitsJob = Start-Job -ScriptBlock {
  param($Username)
  $headers = @{
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
  }
  $resp = Invoke-RestMethod -Uri "https://api.github.com/search/commits?q=author:$Username&per_page=1" -Headers $headers
  $resp.total_count
} -ArgumentList $Username

# 等待期间显示旋转动画
$spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$i = 0
while ($starsJob.State -eq 'Running' -or $commitsJob.State -eq 'Running') {
  Write-Host -NoNewline "`r  $($spinner[$i % $spinner.Length]) fetching ..."
  Start-Sleep -Milliseconds 100
  $i++
}
Write-Host "`r  " -NoNewline
Write-Host ""

$stars = Receive-Job -Job $starsJob
$commits = Receive-Job -Job $commitsJob
Remove-Job -Job $starsJob, $commitsJob

# ---- 校验结果 ------------------------------------------------------------
if ($null -eq $stars) { $stars = 0 }
if ($null -eq $commits) { $commits = 0 }

$starsFmt = Short-Count -Value ([long]$stars)
$commitsFmt = Short-Count -Value ([long]$commits)

Write-Host "  stars=$starsFmt, commits=$commitsFmt"

# ---- [2/3] 更新 tex 文件 -------------------------------------------------
Write-Host "[2/3] Updating \ghstats in $TexFile ..."

$content = Get-Content -LiteralPath $TexFile -Raw -Encoding UTF8
$regex = [regex]'\\+ghstats\{[^}]*\}\{[^}]*\}'
$newContent = $regex.Replace(
  $content,
  [System.Text.RegularExpressions.MatchEvaluator]{
    param($match)
    "\ghstats{$starsFmt}{$commitsFmt}"
  }
)

if ($newContent -notmatch '\\ghstats\{') {
  throw "Error: failed to update ghstats in '$TexFile'"
}

if ($newContent -ceq $content) {
  Write-Host "Stats unchanged. No file rewrite needed."
} else {
  Set-Content -LiteralPath $TexFile -Value $newContent -Encoding UTF8 -NoNewline
  Write-Host "Stats updated in '$TexFile'."
}

# ---- [3/3] 完成 ----------------------------------------------------------
Write-Host "[3/3] Done."
