# LaTeX Resume Template / LaTeX 简历模板

A modern, clean LaTeX resume/CV template designed for Chinese tech professionals. Built with XeLaTeX and `ctexart`, featuring custom commands for projects, education, publications, and GitHub stats auto-fetching.

面向国内技术从业者的现代简洁 LaTeX 简历模板。基于 XeLaTeX + ctexart，提供项目经历、教育背景、科研成果等自定义命令，支持 GitHub 数据自动获取。

## Prerequisites / 环境要求

| Tool | Purpose |
|------|---------|
| XeLaTeX | PDF compilation (TeX Live / MiKTeX) |
| curl | GitHub API requests (stats script only) |
| jq | JSON parsing (stats script only) |
| perl | Text replacement (stats script only) |

**LaTeX packages required:** `ctex`, `fontawesome5`, `geometry`, `enumitem`, `titlesec`, `xcolor`, `hyperref`, `bookmark`, `eso-pic`

## Directory Structure / 目录结构

```
template/         Resume template
  CV.tex          Main LaTeX source
script/           Build scripts
  update_github_stats.sh    Linux/macOS
  update_github_stats.ps1   Windows (PowerShell)
```

## Quick Start / 快速开始

1. **Clone** this repository
2. **Edit** `template/CV.tex` — replace the example content with your own information
3. **Update GitHub stats** (optional):

```bash
# Linux/macOS
./script/update_github_stats.sh your-github-username

# Windows (PowerShell)
.\script\update_github_stats.ps1 -Username your-github-username
```

4. **Compile** with XeLaTeX:

```bash
cd template
xelatex CV.tex
xelatex CV.tex   # run twice for proper layout
```

The output `CV.pdf` will be in the `template/` directory.

## GitHub Stats Script / GitHub 数据脚本

The script fetches your total stars and commits from the GitHub API and updates the `\ghstats{stars}{commits}` command in `CV.tex`.

```bash
# Default: update ../template/CV.tex
./script/update_github_stats.sh your-username

# Specify a different .tex file
./script/update_github_stats.sh your-username path/to/your.tex
```

## Custom Commands Reference / 自定义命令参考

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
