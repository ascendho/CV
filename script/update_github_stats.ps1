param(
  [string]$Username = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$TexFile = "..\template\CV.tex"

function Require-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Error: missing required command '$Name'"
  }
}

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

if (-not (Test-Path -LiteralPath $TexFile)) {
  throw "Error: '$TexFile' not found"
}

# 如果没有传用户名，从 tex 文件中自动提取
if (-not $Username) {
  $content = Get-Content -LiteralPath $TexFile -Raw -Encoding UTF8
  if ($content -match '\\ghlink\{https://github\.com/([^}]+)\}') {
    $Username = $Matches[1]
    Write-Host "Detected GitHub username from tex file: @$Username"
  } else {
    throw "Error: could not detect GitHub username from '$TexFile'. Please pass -Username."
  }
}

Write-Host "[1/3] Fetching GitHub stars for @$Username ..."
$repoResp = Invoke-RestMethod -Uri "https://api.github.com/search/repositories?q=user:$Username&per_page=100"
$stars = ($repoResp.items | Measure-Object -Property stargazers_count -Sum).Sum
if ($null -eq $stars) { $stars = 0 }

Write-Host "[2/3] Fetching GitHub commits for @$Username ..."
$headers = @{
  Accept = "application/vnd.github+json"
  "X-GitHub-Api-Version" = "2022-11-28"
}
$commitResp = Invoke-RestMethod -Uri "https://api.github.com/search/commits?q=author:$Username&per_page=1" -Headers $headers
$commits = $commitResp.total_count
if ($null -eq $commits) { $commits = 0 }

$starsFmt = Short-Count -Value ([long]$stars)
$commitsFmt = Short-Count -Value ([long]$commits)

Write-Host "[3/3] Updating LaTeX stats: stars=$starsFmt, commits=$commitsFmt"
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

Write-Host "Done."
