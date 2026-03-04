#!/bin/bash

# Bounty Opportunity Scout
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

# Simple search using GitHub CLI with timeout
search_queries=(
    "label:bounty"
    "label:reward"
    'label:"help wanted"'
    'label:"good first issue"'
)

found_opportunities=()

for query in "${search_queries[@]}"; do
    echo "Searching for: $query" >&2
    
    # Try different search approaches with timeout
    if ! results=$(timeout $TIMEOUT gh api "search/issues?q=${query}+type:issue+state:open" --jq '.items' 2>/dev/null); then
        echo "Search timed out: $query" >&2
        continue
    fi
    
    if [ "$results" != "null" ] && [ "$(echo "$results" | jq length 2>/dev/null)" -gt 0 ]; then
        if ! echo "$results" | jq -c '.[]' 2>/dev/null | while read -r issue; do
            number=$(echo "$issue" | jq -r '.number')
            title=$(echo "$issue" | jq -r '.title')
            body=$(echo "$issue" | jq -r '.body')
            url=$(echo "$issue" | jq -r '.html_url')
            
            # Extract repository info
            repo_full=$(echo "$issue" | jq -r '.repository_url' | sed 's|https://api.github.com/repos/||')
            owner=$(echo "$repo_full" | cut -d'/' -f1)
            repo=$(echo "$repo_full" | cut -d'/' -f2)
            
            # Get labels
            labels=$(echo "$issue" | jq -r '.labels[].name' | tr '[:upper:]' '[:lower:]')
            
            # Check for monetary indicators
            reward_type="unknown"
            reward_amount=""
            
            if echo "$body" | grep -q '\$[0-9]'; then
                reward_type="monetary"
                amount=$(echo "$body" | grep '\$[0-9]' | grep -o '\$[0-9]*' | head -1)
                reward_amount="$amount"
            elif echo "$labels" | grep -q -E '(bounty|reward)'; then
                reward_type="monetary"
            elif echo "$body" | grep -qi -E '(token|nft|badge|recognition)'; then
                reward_type="non-monetary"
                keyword=$(echo "$body" | grep -i -E '(token|nft|badge|recognition)' | head -1)
                reward_amount="$keyword"
            fi
            
            if [ "$reward_type" != "unknown" ]; then
                opportunity=$(jq -n --arg number "$number" --arg title "$title" --arg owner "$owner" --arg repo "$repo" --arg url "$url" --arg reward_type "$reward_type" --arg reward_amount "$reward_amount" '{"number":$number,"title":$title,"owner":$owner,"repo":$repo,"url":$url,"reward_type":$reward_type,"reward_amount":$reward_amount}')
                found_opportunities+=("$opportunity")
            fi
        done; then
        echo "Processing results failed: $query" >&2
        continue
    fi
    fi
    
    sleep 2
done

# Output results
if [ ${#found_opportunities[@]} -eq 0 ]; then
    echo '[]'
else
    printf '%s\n' "${found_opportunities[@]}" | jq -s '.'
fi

# 确保所有 gh 子进程都被正确清理
pkill -f "gh api" 2>/dev/null || true