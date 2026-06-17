# LaTeX Resume Template / LaTeX 简历模板

A modern, clean LaTeX resume/CV template designed for Chinese tech professionals. Built with XeLaTeX and `ctexart`, featuring GitHub stats auto-fetching, dual-mode PDF generation (full & anonymized), and cross-platform build scripts.

面向国内技术从业者的现代简洁 LaTeX 简历模板。基于 XeLaTeX + ctexart，支持 GitHub 数据自动获取、双模式 PDF 生成（完整版 & 匿名公开版）以及跨平台构建脚本。

## Preview / 预览

Build the template first to generate your own preview:

```bash
./script/update_resume_stats_and_build.sh --build-only
```

## Prerequisites / 环境要求

| Tool | Purpose |
|------|---------|
| XeLaTeX | PDF compilation (TeX Live / MiKTeX) |
| curl | GitHub API requests |
| jq | JSON parsing |
| perl | In-place text replacement |

**LaTeX packages required:** `ctex`, `fontawesome5`, `geometry`, `enumitem`, `titlesec`, `xcolor`, `hyperref`, `bookmark`, `eso-pic`

## Directory Structure / 目录结构

```
template/          Resume template
  CV.tex          Main LaTeX source
script/           Build scripts
  update_resume_stats_and_build.sh   Linux/macOS
  build_resume.ps1                   Windows (PowerShell)
```

## Quick Start / 快速开始

1. **Clone** this repository
2. **Edit** `template/CV.tex` — replace the example content with your own information
3. **Run** the build script:

```bash
# Linux/macOS
./script/update_resume_stats_and_build.sh your-github-username

# Windows (PowerShell)
.\script\build_resume.ps1 -Username your-github-username
```

4. **Find your PDFs** in the `template/` directory:
   - `CV.pdf` — full version (Chinese name, phone number)
   - `resume.pdf` — public/anonymized version (English name only, no phone)

## `\PUBLICRESUME` Toggle / 公开版开关

The template supports a compile-time toggle for generating an anonymized public resume:

| | Full (`CV.pdf`) | Public (`resume.pdf`) |
|---|---|---|
| Name | Chinese name (张三) | English name (Zhang San) |
| Phone | Visible | Hidden |

The toggle is controlled by defining `\PUBLICRESUME` at compile time. The build scripts generate both versions automatically — no manual configuration needed.

## Build Script Usage / 构建脚本用法

Both scripts support three modes:

```bash
# Full workflow: fetch GitHub stats + build both PDFs (default)
./script/update_resume_stats_and_build.sh your-username

# Update stats only (no PDF build)
./script/update_resume_stats_and_build.sh --update-only your-username

# Build PDFs only (skip GitHub API calls)
./script/update_resume_stats_and_build.sh --build-only
```

The second argument optionally specifies the `.tex` file path (defaults to `../template/CV.tex`).

## Custom Commands Reference / 自定义命令参考

The template defines several LaTeX commands to simplify resume writing:

| Command | Purpose |
|---------|---------|
| `\entry{title}{role}{desc}{date}` | Generic entry with title, role, description, and date |
| `\projentry{name}{tag}{code-url}{demo-url}` | Project header with name, optional tag, code & demo links |
| `\eduentry{school}{major}{degree}{dates}` | Education entry with four-column layout |
| `\ghlink{url}{text}` | Blue-colored hyperlink (for GitHub/personal links) |
| `\ghstats{stars}{commits}` | GitHub star & commit count display |
| `\codelink{url}` | Code repository link icon |
| `\demolink{url}` | Demo video link icon |
| `\paperlink{url}` | External link icon for papers |
| `\projkeyword{text}` | Gray keyword styling (for English terms) |
| `\projkeywordzh{text}` | Gray keyword styling (for Chinese terms) |
| `\projmetric{text}` | Blue metric highlighting (for key numbers) |

## Font Notes / 字体说明

- **Latin text:** Times New Roman (requires the font to be installed)
- **CJK text:** Auto-selected by `ctex` per platform (macOS: Songti SC, Windows: SimSun, Linux: Noto Serif CJK)
- If the output looks incorrect, ensure CJK fonts are installed on your system

## License

MIT
