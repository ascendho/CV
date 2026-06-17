# LaTeX 简历模板

面向国内技术从业者的现代简洁 LaTeX 简历模板。基于 XeLaTeX + ctexart，提供项目经历、教育背景、科研成果等自定义命令，支持 GitHub 数据自动获取。

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
```

## 快速开始

1. **克隆**本仓库
2. **编辑** `template/CV.tex`，将示例内容替换为你自己的信息
3. **更新 GitHub 数据**（可选）：

```bash
# Linux/macOS
./script/update_github_stats.sh 你的GitHub用户名

# Windows (PowerShell)
.\script\update_github_stats.ps1 -Username 你的GitHub用户名
```

4. **编译** PDF：

```bash
cd template
xelatex CV.tex
xelatex CV.tex   # 运行两次以确保版式正确
```

编译生成的 `CV.pdf` 位于 `template/` 目录下。

## GitHub 数据脚本

脚本从 GitHub API 获取你的 star 总数和 commit 总数，并更新 `CV.tex` 中的 `\ghstats{stars}{commits}` 命令。

```bash
# 默认更新 ../template/CV.tex
./script/update_github_stats.sh 你的用户名

# 指定其他 .tex 文件
./script/update_github_stats.sh 你的用户名 path/to/your.tex
```

## 自定义命令参考

| 命令 | 用途 |
|------|------|
| `\entry{标题}{角色}{描述}{日期}` | 通用条目：标题、角色、描述、日期 |
| `\projentry{名称}{标签}{代码链接}{演示链接}` | 项目标题行：名称、可选标签、代码和演示链接 |
| `\eduentry{学校}{专业}{学位}{日期}` | 教育经历：四列布局 |
| `\ghlink{url}{文本}` | 蓝色超链接（用于 GitHub / 个人主页） |
| `\ghstats{stars}{commits}` | GitHub star 与 commit 数量展示 |
| `\codelink{url}` | 代码仓库链接图标 |
| `\demolink{url}` | 演示视频链接图标 |
| `\paperlink{url}` | 论文外部链接图标 |
| `\projkeyword{文本}` | 灰色关键词（英文术语） |
| `\projkeywordzh{文本}` | 灰色关键词（中文术语） |
| `\projmetric{文本}` | 蓝色指标高亮（关键数字） |

## 字体说明

- **拉丁文字：** Times New Roman（需安装该字体）
- **中文字体：** 由 `ctex` 根据平台自动选择（macOS: Songti SC，Windows: SimSun，Linux: Noto Serif CJK）
- 如果输出效果异常，请检查系统中文字体是否安装完整

## License

MIT
