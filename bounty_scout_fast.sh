#!/bin/bash

# Bounty Opportunity Scout - Fast Version
# Scans for issues with bounties/rewards/help wanted labels

set -e

# 设置超时时间 (30秒)
TIMEOUT=30

# Check GitHub permissions in sequence with timeout
# 1) gh auth status 是否已登录
if ! timeout $TIMEOUT gh auth status &>/dev/null; then
    echo "GitHub not authenticated" >&2
    exit 1
fi

# 2) 是否可访问基础 API (简化权限检查)
if ! timeout $TIMEOUT gh api user &>/dev/null; then
    echo "Cannot access GitHub API (permission denied)" >&2
    exit 1
fi

echo "GitHub permissions verified successfully"

# Simple search with time limits and timeout
found_opportunities=()

# Search open issues with bounty labels created in last 7 days
if ! results=$(timeout $TIMEOUT gh api "search/issues?q=label:bounty+type:issue+state:open+created:>=2026-02-26" --jq '.items' 2>/dev/null); then
    results='[]'
fi

if [ "$(echo "$results" | jq length 2>/dev/null)" -gt 0 ]; then
    if ! echo "$results" | jq -c '.[]' 2>/dev/null | while read -r issue; do
        number=$(echo "$issue" | jq -r '.number')
        title=$(echo "$issue" | jq -r '.title')
        body=$(echo "$issue" | jq -r '.body')
        url=$(echo "$issue" | jq -r '.html_url')
        repo_full=$(echo "$issue" | jq -r '.repository_url' | sed 's|https://api.github.com/repos/||')
        owner=$(echo "$repo_full" | cut -d'/' -f1)
        repo=$(echo "$repo_full" | cut -d'/' -f2)
        
        # Extract reward information
        reward_type="monetary"
        reward_amount=""
        
        if echo "$body" | grep -q '\$[0-9]'; then
            reward_amount=$(echo "$body" | grep -o '\$[0-9]*' | head -1)
        else
            reward_amount="Undisclosed"
        fi
        
        opportunity=$(jq -n --arg number "$number" --arg title "$title" --arg owner "$owner" --arg repo "$repo" --arg url "$url" --arg reward_type "$reward_type" --arg reward_amount "$reward_amount" '{"number":$number,"title":$title,"owner":$owner,"repo":$repo,"url":$url,"reward_type":$reward_type,"reward_amount":$reward_amount}')
        found_opportunities+=("$opportunity")
    done; then
    echo "Processing results failed" >&2
    fi
fi

# Output results
if [ ${#found_opportunities[@]} -eq 0 ]; then
    echo '[]'
else
    printf '%s\n' "${found_opportunities[@]}" | jq -s '.'
fi

# 确保所有 gh 子进程都被正确清理
pkill -f "gh api" 2>/dev/null || true
