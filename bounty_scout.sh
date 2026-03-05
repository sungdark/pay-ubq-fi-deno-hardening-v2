#!/bin/bash
set -euo pipefail

# 赏金任务扫描脚本
echo "=== 开始扫描可变现任务 ==="

# 检查 GH 权限
if ! gh auth status &>/dev/null; then
    echo "未登录 GitHub，无法执行任务"
    exit 1
fi

# 扫描标准搜索：bounty OR reward OR "help wanted" 有奖金的任务
echo "搜索有奖金的可变现任务..."
SEARCH_QUERY="\"bounty\" OR \"reward\" OR \"help wanted\" sort:updated-desc"
gh search issues --repo-type all --state open --limit 20 -- q="$SEARCH_QUERY" --json title,body,url,repository,comments,createdAt,updatedAt,labels 2>/dev/null || {
    echo "搜索失败，检查网络或权限"
    exit 1
}

echo "=== 任务扫描完成 ==="
echo "扫描到 $(gh search issues --repo-type all --state open --limit 20 -- q="$SEARCH_QUERY" | wc -l) 个相关任务"

# 简单的筛选逻辑（实际生产环境可以更复杂）
echo "
=== 已找到的可变现任务 ==="
gh search issues --repo-type all --state open --limit 5 -- q="$SEARCH_QUERY" -- sort updated-desc
