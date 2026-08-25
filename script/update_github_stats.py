#!/usr/bin/env python3
"""update_github_stats.py — 从 GitHub API 获取 star 与 commit 总数，
更新 ../template/CV.tex 中的 \\ghstats{stars}{commits}。

跨平台（Windows / macOS / Linux），仅需 Python 3，纯标准库、无需 pip 安装。

用法：
  python3 script/update_github_stats.py [github-username]
  python3 script/update_github_stats.py -u github-username
  （Windows 上请使用 python，macOS / Linux 上使用 python3）

不传用户名时，脚本自动从 CV.tex 的 \\ghlink 命令中提取。

可选：在仓库根目录创建 .env 文件（参考 .env.example）写入
GITHUB_TOKEN=你的Token，可提升 GitHub API 限额（匿名约 10 次/分钟，
带 Token 约 30 次/分钟）。.env 已被 gitignore，不会提交。
也支持直接设置 GITHUB_TOKEN 环境变量（优先级更高）。
"""
import json
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEX_FILE = os.path.normpath(os.path.join(SCRIPT_DIR, os.pardir, "template", "CV.tex"))
ENV_FILE = os.path.normpath(os.path.join(SCRIPT_DIR, os.pardir, ".env"))
API_BASE = "https://api.github.com"
TIMEOUT = 30   # 单个请求超时（秒）
MAX_PAGES = 10  # GitHub Search API 最多返回 1000 条结果


class StatsError(Exception):
    """业务错误：携带友好提示信息，直接退出。"""


# ---- 工具函数 ------------------------------------------------------------

def parse_env_file(path):
    """解析 .env 文件中的 KEY=VALUE 行，返回字典；文件不存在返回空字典。"""
    result = {}
    try:
        with open(path, "r", encoding="utf-8-sig") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip("'\"")
                if key:
                    result[key] = value
    except OSError:
        pass
    return result


def get_token():
    """获取 GitHub Token：优先读环境变量，其次读仓库根目录的 .env 文件。"""
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:
        return token
    return parse_env_file(ENV_FILE).get("GITHUB_TOKEN", "").strip()


def build_headers():
    """构造 GitHub API 请求头；检测到 Token 时自动带上认证。"""
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "cv-github-stats-updater",
    }
    token = get_token()
    if token:
        headers["Authorization"] = "Bearer " + token
    return headers


def api_get_json(url):
    """GET 指定的 GitHub API 地址并解析 JSON，失败时抛出 StatsError。"""
    req = urllib.request.Request(url, headers=build_headers())
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code in (403, 429):
            raise StatsError(
                "GitHub API 限流（HTTP %d）。请稍后重试，或设置 GITHUB_TOKEN "
                "环境变量以提升限额。" % e.code
            )
        if e.code == 401:
            raise StatsError("GITHUB_TOKEN 无效或已过期（HTTP 401），请检查或取消该环境变量。")
        raise StatsError("GitHub API 请求失败（HTTP %d）：%s" % (e.code, url))
    except urllib.error.URLError as e:
        raise StatsError(
            "无法连接 api.github.com：%s。\n"
            "  如在国内，可尝试使用网络加速工具后重试。" % getattr(e, "reason", e)
        )
    except TimeoutError:
        raise StatsError("请求超时，请检查网络后重试。")
    except json.JSONDecodeError:
        raise StatsError("GitHub API 返回了无法解析的内容：%s" % url)


def fetch_stars(username):
    """分页拉取该用户所有仓库的 star 总数（最多 1000 个仓库）。"""
    stars = 0
    page = 1
    while page <= MAX_PAGES:
        url = "%s/search/repositories?q=user:%s&per_page=100&page=%d" % (
            API_BASE, urllib.parse.quote(username, safe=""), page
        )
        resp = api_get_json(url)
        items = resp.get("items") or []
        stars += sum(int(item.get("stargazers_count") or 0) for item in items)
        total = int(resp.get("total_count") or 0)
        if page * 100 >= total:
            break
        page += 1
    return stars


def fetch_commits(username):
    """获取该用户 commit 总数（只读 total_count，per_page=1 最小化响应）。"""
    url = "%s/search/commits?q=author:%s&per_page=1" % (
        API_BASE, urllib.parse.quote(username, safe="")
    )
    resp = api_get_json(url)
    return int(resp.get("total_count") or 0)


def pick_spinner():
    """按当前终端编码挑选旋转动画字符，不支持时回退到 ASCII。"""
    for chars in ("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏", "|/-\\"):
        try:
            chars.encode(sys.stdout.encoding or "utf-8")
            return chars
        except (UnicodeEncodeError, LookupError):
            continue
    return "|/-\\"


def run_parallel(tasks):
    """并行执行任务列表，等待期间显示旋转动画，返回结果列表。"""
    results = [None] * len(tasks)
    errors = [None] * len(tasks)

    def worker(idx, fn):
        try:
            results[idx] = fn()
        except BaseException as e:  # 带回主线程统一处理
            errors[idx] = e

    threads = [
        threading.Thread(target=worker, args=(i, fn), daemon=True)
        for i, fn in enumerate(tasks)
    ]
    for t in threads:
        t.start()

    spinner = pick_spinner()
    frame = 0
    while any(t.is_alive() for t in threads):
        sys.stdout.write("\r  %s fetching ..." % spinner[frame % len(spinner)])
        sys.stdout.flush()
        time.sleep(0.1)
        frame += 1
    sys.stdout.write("\r" + " " * 40 + "\r")  # 清除动画行（兼容旧版 Windows 控制台）
    sys.stdout.flush()

    for e in errors:
        if e is not None:
            raise e
    return results


def short_count(n):
    """将大数字转为人类可读的短格式：1200 → 1.2k，1500000 → 1.5m。"""
    for threshold, suffix in ((1000000, "m"), (1000, "k")):
        if n >= threshold:
            text = ("%.1f" % (n / threshold)).rstrip("0").rstrip(".")
            return text + suffix
    return str(n)


def read_tex():
    """以 UTF-8 读入 CV.tex 原文（字节级读写，保留原有换行符）。"""
    try:
        with open(TEX_FILE, "rb") as f:
            return f.read().decode("utf-8")
    except FileNotFoundError:
        raise StatsError("找不到 '%s'，请确认在仓库内运行本脚本。" % TEX_FILE)
    except UnicodeDecodeError:
        raise StatsError("'%s' 不是有效的 UTF-8 文件。" % TEX_FILE)


def detect_username(text):
    """从 CV.tex 的 \\ghlink 命令中提取 GitHub 用户名。"""
    m = re.search(r"\\ghlink\{https://github\.com/([^}]+)\}", text)
    return m.group(1) if m else None


def update_ghstats(text, stars_fmt, commits_fmt):
    """替换文本中所有 \\ghstats{..}{..}，返回 (新文本, 替换次数)。"""
    replacement = "\\ghstats{%s}{%s}" % (stars_fmt, commits_fmt)
    return re.subn(r"\\ghstats\{[^}]*\}\{[^}]*\}", lambda _m: replacement, text)


# ---- 主流程 --------------------------------------------------------------

def parse_args(argv):
    """解析命令行参数，返回用户名（可为空字符串，表示自动检测）。"""
    username = ""
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in ("-u", "--username"):
            if i + 1 >= len(argv):
                raise StatsError("'%s' 需要一个用户名参数。" % arg)
            username = argv[i + 1]
            i += 2
        elif arg in ("-h", "--help"):
            print(__doc__.strip())
            sys.exit(0)
        elif arg.startswith("-") and arg != "-":
            raise StatsError("未知参数 '%s'（使用 -h 查看帮助）。" % arg)
        else:
            if username:
                raise StatsError("只需一个用户名参数。")
            username = arg
            i += 1
    return username


def main(argv):
    username = parse_args(argv[1:])
    text = read_tex()

    # ---- 解析用户名 --------------------------------------------------------
    # 优先使用命令行参数，否则从 tex 文件中自动检测
    if not username:
        username = detect_username(text)
        if not username:
            raise StatsError(
                "无法从 '%s' 的 \\ghlink 中检测到 GitHub 用户名，请将其作为参数传入。" % TEX_FILE
            )
        print("Detected GitHub username from tex file: @%s" % username)

    # ---- [1/3] 并行获取 stars 和 commits -------------------------------------
    print("[1/3] Fetching GitHub stats for @%s ..." % username)
    stars, commits = run_parallel(
        [
            lambda: fetch_stars(username),
            lambda: fetch_commits(username),
        ]
    )

    # ---- 校验结果 ------------------------------------------------------------
    if not isinstance(stars, int) or stars < 0:
        raise StatsError("failed to parse stars count")
    if not isinstance(commits, int) or commits < 0:
        raise StatsError("failed to parse commit count")

    stars_fmt = short_count(stars)
    commits_fmt = short_count(commits)
    print("  stars=%s, commits=%s" % (stars_fmt, commits_fmt))

    # ---- [2/3] 更新 tex 文件 -------------------------------------------------
    print("[2/3] Updating \\ghstats in %s ..." % TEX_FILE)
    new_text, count = update_ghstats(text, stars_fmt, commits_fmt)
    if count == 0:
        raise StatsError("failed to update ghstats in '%s'" % TEX_FILE)

    if new_text == text:
        print("Stats unchanged. No file rewrite needed.")
    else:
        with open(TEX_FILE, "wb") as f:
            f.write(new_text.encode("utf-8"))
        print("Stats updated in '%s'." % TEX_FILE)

    # ---- [3/3] 完成 ----------------------------------------------------------
    print("[3/3] Done.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except StatsError as e:
        print("Error: %s" % e, file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted.", file=sys.stderr)
        sys.exit(130)
