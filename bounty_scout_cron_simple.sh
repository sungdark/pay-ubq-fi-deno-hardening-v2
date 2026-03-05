#!/bin/bash

# Bounty Opportunity Scout - Simple Version
# Scans for issues with bounties/rewards/help wanted labels with explicit payment

set -e

# Load configuration
source /root/.openclaw/workspace/bounty_scout_config.sh

CURRENT_HOUR=$(date +"%H00")
REPORT_FILE="/root/.openclaw/workspace/战报_${CURRENT_HOUR}.txt"

echo "$(date +"%Y-%m-%d %H:%M:%S") - Starting bounty scout" >> "$LOG_FILE"

# Check authentication
if ! gh auth status &>/dev/null; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - GitHub not authenticated" >> "$LOG_FILE"
    exit 1
fi

found_opportunities=()

# Search for bounty issues with timeout of 60 seconds
if ! result=$(timeout 60 gh api "search/issues?q=label:bounty+type:issue+state:open" --jq '.items[0:5]'); then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Search failed" >> "$LOG_FILE"
    echo "[]"
    exit 0
fi

# Process results
if [ -n "$result" ] && [ "$result" != "null" ]; then
    while IFS= read -r issue; do
        if [ -z "$issue" ] || [ "$issue" = "null" ]; then continue; fi
        
        number=$(echo "$issue" | jq -r '.number')
        title=$(echo "$issue" | jq -r '.title')
        body=$(echo "$issue" | jq -r '.body')
        url=$(echo "$issue" | jq -r '.html_url')
        repo_full=$(echo "$issue" | jq -r '.repository_url' | sed 's|https://api.github.com/repos/||')
        owner=$(echo "$repo_full" | cut -d'/' -f1)
        repo=$(echo "$repo_full" | cut -d'/' -f2)
        
        has_explicit_payment=false
        
        if echo "$body" | grep -q -i -E '\$[0-9]|reward.*\d|payment.*\d|compensation.*\d|bounty.*\d|lifetime.*license|rtc.*\d'; then
            has_explicit_payment=true
        fi
        
        if [ "$has_explicit_payment" = true ]; then
            reward_type="monetary"
            reward_amount="Undisclosed"
            
            if echo "$body" | grep -q '\$[0-9]'; then
                reward_amount=$(echo "$body" | grep -o '\$[0-9]*' | head -1)
            elif echo "$body" | grep -qi 'lifetime.*license'; then
                reward_type="license"
                reward_amount="Lifetime Commercial License"
            elif echo "$body" | grep -qi 'rtc.*\d'; then
                reward_type="token"
                reward_amount=$(echo "$body" | grep -o 'RTC[0-9]*\|[0-9]* RTC' | head -1)
            fi
            
            opportunity=$(jq -n --arg number "$number" --arg title "$title" --arg owner "$owner" --arg repo "$repo" --arg url "$url" --arg reward_type "$reward_type" --arg reward_amount "$reward_amount" '{"number":$number,"title":$title,"owner":$owner,"repo":$repo,"url":$url,"reward_type":$reward_type,"reward_amount":$reward_amount}')
            found_opportunities+=("$opportunity")
        fi
    done < <(echo "$result" | jq -c '.[]')
fi

# Generate report
if [ ${#found_opportunities[@]} -eq 0 ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - No bounty opportunities found with explicit payment" >> "$LOG_FILE"
    echo "[]"
else
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Found ${#found_opportunities[@]} bounty opportunities" >> "$LOG_FILE"
    
    # Create report if not exists
    if [ ! -f "$REPORT_FILE" ]; then
        cat > "$REPORT_FILE" << EOF
# 赚钱战报 - $(date +"%Y-%m-%d %H:%M:%S")

## 概览

- 检查时间: $(date +"%Y-%m-%d %H:%M:%S")
- 任务发现数量: ${#found_opportunities[@]}
- 待结算金额: 待计算
- 已到账金额: 0
- 目标金额: 1000

## 任务详情
EOF
    else
        # If report exists, update task count
        sed -i "s/任务发现数量: [0-9]*/任务发现数量: ${#found_opportunities[@]}/" "$REPORT_FILE"
    fi
    
    # Add tasks to report only if not already present
    for opportunity in "${found_opportunities[@]}"; do
        issue_number=$(echo "$opportunity" | jq -r '.number')
        issue_title=$(echo "$opportunity" | jq -r '.title')
        issue_owner=$(echo "$opportunity" | jq -r '.owner')
        issue_repo=$(echo "$opportunity" | jq -r '.repo')
        reward_amount=$(echo "$opportunity" | jq -r '.reward_amount')
        issue_url=$(echo "$opportunity" | jq -r '.url')
        
        # Check if task already exists in report
        if ! grep -q "$issue_owner/$issue_repo #$issue_number" "$REPORT_FILE"; then
            cat >> "$REPORT_FILE" << EOF

### [$issue_owner/$issue_repo #$issue_number]($issue_url)
- 标题: $issue_title
- 奖励金额: $reward_amount
- 状态: 待执行
EOF
        fi
    done
    
    # Output as JSON
    printf '%s\n' "${found_opportunities[@]}" | jq -s '.'
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") - Bounty scout completed" >> "$LOG_FILE"
