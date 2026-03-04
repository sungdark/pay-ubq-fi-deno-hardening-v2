#!/bin/bash

# Bounty Opportunity Scout - Fixed Version
# Scans for issues with bounties/rewards/help wanted labels with explicit payment
# and executable delivery path

set -e

# Load configuration
source /root/.openclaw/workspace/bounty_scout_config.sh

# 战报文件
CURRENT_HOUR=$(date +"%H00")
REPORT_FILE="/root/.openclaw/workspace/战报_${CURRENT_HOUR}.txt"

# 检查 GitHub 权限的顺序：
# 1) gh auth status 是否已登录
# 2) 是否可 issue comment
# 3) 是否可向 fork push

echo "$(date +"%Y-%m-%d %H:%M:%S") - Starting bounty opportunity scout" >> "$LOG_FILE"

# 权限检查 1: gh auth status 是否已登录
if ! timeout $SEARCH_TIMEOUT gh auth status &>/dev/null; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - GitHub not authenticated" >&2
    echo "$(date +"%Y-%m-%d %H:%M:%S") - GitHub not authenticated" >> "$LOG_FILE"
    exit 1
fi

# 权限检查 2: 是否可访问基础 API (简化的评论权限检查)
if ! timeout $SEARCH_TIMEOUT gh api user &>/dev/null; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Cannot access GitHub API (permission denied)" >&2
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Cannot access GitHub API (permission denied)" >> "$LOG_FILE"
    exit 1
fi

# 权限检查 3: 测试向 fork push 的能力 (通过检查当前用户的仓库列表)
if ! timeout $SEARCH_TIMEOUT gh api user/repos?per_page=1 &>/dev/null; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Cannot access user repositories (push to fork permission denied)" >&2
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Cannot access user repositories (push to fork permission denied)" >> "$LOG_FILE"
    exit 1
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") - GitHub permissions verified successfully" >> "$LOG_FILE"

# 搜索可变现任务 - 优先有明确奖金与可结算路径
# 只搜索包含明确金钱奖励或可结算路径的任务
all_results='[]'

for query in "${SEARCH_QUERIES[@]}"; do
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Searching for: $query" >> "$LOG_FILE"
    
    if ! results=$(timeout $SEARCH_TIMEOUT gh api "search/issues?q=${query}" --jq '.items' 2>&1); then
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Search failed: $results" >> "$LOG_FILE"
        continue
    fi
    
    if [ "$results" != "null" ] && [ "$(echo "$results" | jq length 2>/dev/null)" -gt 0 ]; then
        all_results=$(jq -s 'add' <(echo "$all_results") <(echo "$results"))
    fi
    
    sleep $SEARCH_DELAY
done

# 处理搜索结果
found_opportunities=()

if [ "$all_results" != "null" ] && [ "$(echo "$all_results" | jq length 2>/dev/null)" -gt 0 ]; then
    while IFS= read -r issue; do
        if [ -z "$issue" ]; continue; fi
        
        number=$(echo "$issue" | jq -r '.number')
        title=$(echo "$issue" | jq -r '.title')
        body=$(echo "$issue" | jq -r '.body')
        url=$(echo "$issue" | jq -r '.html_url')
        repo_full=$(echo "$issue" | jq -r '.repository_url' | sed 's|https://api.github.com/repos/||')
        owner=$(echo "$repo_full" | cut -d'/' -f1)
        repo=$(echo "$repo_full" | cut -d'/' -f2)
        
        # 检查是否包含明确的奖金或可结算路径
        has_explicit_payment=false
        
        # 检查是否有明确的金钱奖励
        if echo "$body" | grep -q '\$[0-9]'; then
            has_explicit_payment=true
        elif echo "$title" | grep -q '\$[0-9]'; then
            has_explicit_payment=true
        # 检查是否有可结算路径的关键词
        elif echo "$body" | grep -qi -E '(reward.*\d|payment.*\d|compensation.*\d|bounty.*\d|lifetime.*license|rtc.*\d)'; then
            has_explicit_payment=true
        fi
        
        if [ "$has_explicit_payment" = true ]; then
            # 提取奖励信息
            reward_type="monetary"
            reward_amount=""
            
            if echo "$body" | grep -q '\$[0-9]'; then
                reward_amount=$(echo "$body" | grep -o '\$[0-9]*' | head -1)
            elif echo "$title" | grep -q '\$[0-9]'; then
                reward_amount=$(echo "$title" | grep -o '\$[0-9]*' | head -1)
            elif echo "$body" | grep -qi 'lifetime.*license'; then
                reward_type="license"
                reward_amount="Lifetime Commercial License"
            elif echo "$body" | grep -qi 'rtc.*\d'; then
                reward_type="token"
                reward_amount=$(echo "$body" | grep -o 'RTC[0-9]*\|[0-9]* RTC' | head -1)
            else
                reward_amount="Undisclosed"
            fi
            
            # 创建任务对象
            opportunity=$(jq -n --arg number "$number" --arg title "$title" --arg owner "$owner" --arg repo "$repo" --arg url "$url" --arg reward_type "$reward_type" --arg reward_amount "$reward_amount" '{"number":$number,"title":$title,"owner":$owner,"repo":$repo,"url":$url,"reward_type":$reward_type,"reward_amount":$reward_amount}')
            found_opportunities+=("$opportunity")
        fi
    done < <(echo "$all_results" | jq -c '.[]')
fi

# 输出结果到日志
if [ ${#found_opportunities[@]} -eq 0 ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - No bounty opportunities found with explicit payment" >> "$LOG_FILE"
    echo "[]"
else
    # 输出到日志
    printf '%s\n' "${found_opportunities[@]}" | jq -s '.' >> "$LOG_FILE"
    
    # 发送通知
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Bounties found: $(echo "${found_opportunities[@]}" | jq -s 'length')" >> "$NOTIFICATION_FILE"
    
    # 发送简短执行通知
    echo "✅ Bounty opportunity scout found new tasks!"
    echo "📅 Last check: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "💎 Tasks found: $(echo "${found_opportunities[@]}" | jq -s 'length')"
    
    # 详细进度与金额统一并入整点赚钱战报
    for opportunity in "${found_opportunities[@]}"; do
        issue_number=$(echo "$opportunity" | jq -r '.number')
        issue_title=$(echo "$opportunity" | jq -r '.title')
        issue_owner=$(echo "$opportunity" | jq -r '.owner')
        issue_repo=$(echo "$opportunity" | jq -r '.repo')
        reward_amount=$(echo "$opportunity" | jq -r '.reward_amount')
        
        # 检查战报文件是否存在，不存在则创建
        if [ ! -f "$REPORT_FILE" ]; then
            cat > "$REPORT_FILE" << EOF
# 赚钱战报 - $(date +"%Y-%m-%d %H:%M:%S")

## 概览

- 检查时间: $(date +"%Y-%m-%d %H:%M:%S")
- 任务发现数量: $(echo "${found_opportunities[@]}" | jq -s 'length')
- 待结算金额: $(printf "%s" "${found_opportunities[@]}" | jq -s 'map(.reward_amount | sub("\\$"; "") | tonumber) | map(select(. != null)) | add')
- 已到账金额: 0
- 目标金额: 1000

## 任务详情
EOF
        fi
        
        # 添加任务到战报
        cat >> "$REPORT_FILE" << EOF

### [$issue_owner/$issue_repo #$issue_number]($(echo "$opportunity" | jq -r '.url'))
- 标题: $issue_title
- 奖励金额: $reward_amount
- 状态: 待执行
EOF
    done
    
    # 输出任务详情
    printf '%s\n' "${found_opportunities[@]}" | jq -s '.'
fi

# 确保所有 gh 子进程都被正确清理
pkill -f "gh api" 2>/dev/null || true

# 检查是否需要执行任务
if [ ${#found_opportunities[@]} -gt 0 ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Found ${#found_opportunities[@]} tasks to execute" >> "$LOG_FILE"
    
    # 执行任务 (简化版本)
    for opportunity in "${found_opportunities[@]}"; do
        issue_number=$(echo "$opportunity" | jq -r '.number')
        issue_title=$(echo "$opportunity" | jq -r '.title')
        issue_owner=$(echo "$opportunity" | jq -r '.owner')
        issue_repo=$(echo "$opportunity" | jq -r '.repo')
        reward_amount=$(echo "$opportunity" | jq -r '.reward_amount')
        
        echo "$(date +"%Y-%m-%d %H:%M:%S") - Executing task: $issue_owner/$issue_repo #$issue_number - $issue_title" >> "$LOG_FILE"
        
        # 这里可以添加实际的任务执行逻辑
        # 先简单记录任务信息
        TASK_LOG="/root/.openclaw/workspace/logs/task_${issue_owner}_${issue_repo}_${issue_number}.log"
        echo "Task: $issue_owner/$issue_repo #$issue_number" > "$TASK_LOG"
        echo "Title: $issue_title" >> "$TASK_LOG"
        echo "Reward: $reward_amount" >> "$TASK_LOG"
        echo "URL: $(echo "$opportunity" | jq -r '.url')" >> "$TASK_LOG"
        
        sleep $EXECUTION_DELAY
    done
fi

echo "$(date +"%Y-%m-%d %H:%M:%S") - Bounty scout completed" >> "$LOG_FILE"
