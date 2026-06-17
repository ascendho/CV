param(
  [ValidateSet("full", "update-only", "build-only")]
  [string]$Mode = "full",
  [string]$Username = "your-username",
  [string]$TexFile = "..\template\CV.tex",
  [switch]$ShowCleanupWarnings
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

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

function Remove-FileWithRetry {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [int]$MaxRetries = 12,
    [int]$DelayMs = 500
  )

  for ($i = 1; $i -le $MaxRetries; $i++) {
    try {
      if (-not (Test-Path -LiteralPath $Path)) {
        return $true
      }
      Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      return $true
    } catch {
      Start-Sleep -Milliseconds $DelayMs
    }
  }

  return -not (Test-Path -LiteralPath $Path)
}

function Invoke-XeLatex {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$StepName
  )

  & xelatex @Arguments | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Error: xelatex failed at step '$StepName' (exit code: $LASTEXITCODE)."
  }
}

if (-not (Test-Path -LiteralPath $TexFile)) {
  throw "Error: '$TexFile' not found"
}

if ($Mode -ne "update-only") {
  Require-Command -Name "xelatex"
}

$texDir = Split-Path -Parent $TexFile

if ($Mode -ne "build-only") {
  Write-Host "[1/4] Fetching GitHub stars for @$Username ..."
  $repoResp = Invoke-RestMethod -Uri "https://api.github.com/search/repositories?q=user:$Username&per_page=100"
  $stars = ($repoResp.items | Measure-Object -Property stargazers_count -Sum).Sum
  if ($null -eq $stars) { $stars = 0 }

  Write-Host "[2/4] Fetching GitHub commits for @$Username ..."
  $headers = @{
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
  }
  $commitResp = Invoke-RestMethod -Uri "https://api.github.com/search/commits?q=author:$Username&per_page=1" -Headers $headers
  $commits = $commitResp.total_count
  if ($null -eq $commits) { $commits = 0 }

  $starsFmt = Short-Count -Value ([long]$stars)
  $commitsFmt = Short-Count -Value ([long]$commits)

  Write-Host "[3/4] Updating LaTeX stats: stars=$starsFmt, commits=$commitsFmt"
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

  if ($Mode -eq "update-only") {
    Write-Host "Done. Updated $TexFile"
    exit 0
  }
}

Write-Host "[4/5] Building full PDF (CV.pdf) ..."
$fullJobName = "CV"
$publicJobName = "resume"
$buildDirName = ".latex-build"
$buildDir = Join-Path $PSScriptRoot $buildDirName

if (Test-Path -LiteralPath $buildDir) {
  Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

Invoke-XeLatex -StepName "full" -Arguments @(
  "-interaction=nonstopmode",
  "-halt-on-error",
  "-output-directory",
  $buildDirName,
  "-jobname=$fullJobName",
  $TexFile
)
Invoke-XeLatex -StepName "full-rerun" -Arguments @(
  "-interaction=nonstopmode",
  "-halt-on-error",
  "-output-directory",
  $buildDirName,
  "-jobname=$fullJobName",
  $TexFile
)

Write-Host "[5/5] Building public (anonymized) PDF (resume.pdf) ..."
$publicInput = "\def\PUBLICRESUME{1}\input{$TexFile}"
Invoke-XeLatex -StepName "public" -Arguments @(
  "-interaction=nonstopmode",
  "-halt-on-error",
  "-output-directory",
  $buildDirName,
  "-jobname=$publicJobName",
  $publicInput
)
Invoke-XeLatex -StepName "public-rerun" -Arguments @(
  "-interaction=nonstopmode",
  "-halt-on-error",
  "-output-directory",
  $buildDirName,
  "-jobname=$publicJobName",
  $publicInput
)

Copy-Item -LiteralPath (Join-Path $buildDir "$fullJobName.pdf") -Destination (Join-Path $texDir "$fullJobName.pdf") -Force
Copy-Item -LiteralPath (Join-Path $buildDir "$publicJobName.pdf") -Destination (Join-Path $texDir "$publicJobName.pdf") -Force

# 清理临时构建目录及工作目录中历史遗留的辅助文件。
$rootAuxPatterns = @("*.aux", "*.log", "*.out", "*.synctex.gz")
foreach ($pattern in $rootAuxPatterns) {
  $files = Get-ChildItem -LiteralPath . -File -Filter $pattern -ErrorAction SilentlyContinue
  foreach ($file in $files) {
    if (-not (Remove-FileWithRetry -Path $file.FullName) -and $ShowCleanupWarnings) {
      Write-Warning "Could not remove locked file: $($file.Name)"
    }
  }
}

if (Test-Path -LiteralPath $buildDir) {
  try {
    Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction Stop
  } catch {
    if ($ShowCleanupWarnings) {
      Write-Warning "Could not remove temporary build directory: $buildDir"
    }
  }
}

Write-Host "Done. Updated $TexFile and generated:"
Write-Host "  - $(Join-Path $texDir $fullJobName.pdf)"
Write-Host "  - $(Join-Path $texDir $publicJobName.pdf)"
