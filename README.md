# LaTeX 简历模板

<div align="center">

![LaTeX](https://img.shields.io/badge/LaTeX-XeLaTeX-blue?logo=latex)
![License](https://img.shields.io/badge/license-MIT-green)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

</div>

<div align="center">
  <img src="assets/CV-1.png" alt="简历预览" width="600" />
</div>

面向国内技术从业者的现代简洁 LaTeX 简历模板。基于 XeLaTeX + ctexart，提供项目经历、教育背景、科研成果等自定义命令，支持 GitHub star 与 commit 统计数据自动获取。

## 环境要求

| 工具 | 用途 |
|------|------|
| XeLaTeX | PDF 编译（TeX Live / MiKTeX） |
| curl | GitHub API 请求（仅 stats 脚本需要） |
| jq | JSON 解析（仅 stats 脚本需要） |
| perl | 文本替换（仅 stats 脚本需要） |

**依赖的 LaTeX 宏包：** `ctex`、`fontawesome5`、`geometry`、`enumitem`、`titlesec`、`xcolor`、`hyperref`、`bookmark`、`eso-pic`

## 目录结构

```
template/         简历模版
  CV.tex          主 LaTeX 源文件
script/           辅助脚本
  update_github_stats.sh    Linux/macOS
  update_github_stats.ps1   Windows (PowerShell)
assets/           静态资源
  CV-1.png        简历预览图
LICENSE           MIT 许可证
```

## 快速开始

1. **克隆**本仓库
2. **编辑** `template/CV.tex`，将示例内容替换为你自己的信息
3. **更新 GitHub 数据**（可选）：脚本会自动从 `CV.tex` 中检测你的 GitHub 用户名，也可以手动指定。

> **注意：** 脚本需要访问 GitHub API。如果你在国内遇到 `Failed to connect to api.github.com` 等网络错误，可以使用 [Watt Toolkit](https://steampp.net/)（原 Steam++）等工具加速 GitHub 访问。

```bash
# Linux/macOS — 自动检测用户名
./script/update_github_stats.sh
# 或手动指定
./script/update_github_stats.sh 你的GitHub用户名

# Windows (PowerShell)
.\script\update_github_stats.ps1
# 或手动指定
.\script\update_github_stats.ps1 -Username 你的GitHub用户名
```

4. **编译** PDF：

```bash
cd template
xelatex CV.tex
xelatex CV.tex   # 运行两次以确保版式正确
```

编译生成的 `CV.pdf` 位于 `template/` 目录下。

## 贡献

欢迎提交 Issue 和 Pull Request！

- 如果你有功能建议或发现了 bug，请提交 [Issue](https://github.com/ascendho/CV/issues)
- 如果你想贡献代码，请先 Fork 本仓库，修改后提交 PR
- 请确保 PR 描述清晰，说明修改的内容和原因

## 许可证

本项目使用 [MIT License](LICENSE)。
