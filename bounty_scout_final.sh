#!/bin/bash

# Bounty Opportunity Scout - Final Version
# Scans for issues with bounties/rewards/help wanted labels with explicit payment

set -e

# Configuration
LOG_DIR="/root/.openclaw/workspace/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bounty_scout_final.log"
CURRENT_HOUR=$(date +"%H00")
REPORT_FILE="/root/.openclaw/workspace/战报_${CURRENT_HOUR}.txt"

echo "$(date +"%Y-%m-%d %H:%M:%S") - Starting bounty scout" >> "$LOG_FILE"

# Check GitHub authentication
if ! gh auth status &>/dev/null; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - GitHub not authenticated" >> "$LOG_FILE"
    echo "[]"
    exit 1
fi

found_opportunities=()

# Search for bounty issues - limit to 5 results for testing
SEARCH_QUERY="label:bounty+type:issue+state:open"
echo "$(date +"%Y-%m-%d %H:%M:%S") - Searching for: $SEARCH_QUERY" >> "$LOG_FILE"

# Get raw response
RAW_RESPONSE=$(timeout 60 gh api "search/issues?q=${SEARCH_QUERY}" 2>&1)
if [ $? -ne 0 ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Search failed: $RAW_RESPONSE" >> "$LOG_FILE"
    echo "[]"
    exit 0
fi

# Extract items
ITEMS=$(echo "$RAW_RESPONSE" | jq -r '.items[0:5]' 2>&1)

if [ "$(echo "$ITEMS" | jq 'length')" -eq 0 ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - No bounty issues found" >> "$LOG_FILE"
    echo "[]"
    exit 0
fi

# Process each item
while IFS= read -r issue; do
    if [ -z "$issue" ] || [ "$issue" = "null" ] || [ "$issue" = "" ]; then continue; fi
    
    number=$(echo "$issue" | jq -r '.number' 2>/dev/null)
    if [ "$number" = "null" ] || [ -z "$number" ]; then continue; fi
    
    title=$(echo "$issue" | jq -r '.title' 2>/dev/null)
    body=$(echo "$issue" | jq -r '.body' 2>/dev/null)
    url=$(echo "$issue" | jq -r '.html_url' 2>/dev/null)
    repo_full=$(echo "$issue" | jq -r '.repository_url' 2>/dev/null | sed 's|https://api.github.com/repos/||')
    owner=$(echo "$repo_full" | cut -d'/' -f1)
    repo=$(echo "$repo_full" | cut -d'/' -f2)
    
    # Check for explicit payment
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
        
        # Create task object
        opportunity=$(jq -n --arg number "$number" --arg title "$title" --arg owner "$owner" --arg repo "$repo" --arg url "$url" --arg reward_type "$reward_type" --arg reward_amount "$reward_amount" '{"number":$number,"title":$title,"owner":$owner,"repo":$repo,"url":$url,"reward_type":$reward_type,"reward_amount":$reward_amount}')
        found_opportunities+=("$opportunity")
    fi
done < <(echo "$ITEMS" | jq -c '.[]')

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
    fi
    
    # Add tasks to report
    for opportunity in "${found_opportunities[@]}"; do
        issue_number=$(echo "$opportunity" | jq -r '.number')
        issue_title=$(echo "$opportunity" | jq -r '.title')
        issue_owner=$(echo "$opportunity" | jq -r '.owner')
        issue_repo=$(echo "$opportunity" | jq -r '.repo')
        reward_amount=$(echo "$opportunity" | jq -r '.reward_amount')
        
        cat >> "$REPORT_FILE" << EOF

### [$issue_owner/$issue_repo #$issue_number]($(echo "$opportunity" | jq -r '.url'))
- 标题: $issue_title
- 奖励金额: $reward_amount
- 状态: 待执行
EOF
    done
    
    # Output as JSON
    printf '%s\n' "${found_opportunities[@]}" | jq -s '.'
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") - Bounty scout completed" >> "$LOG_FILE"
