#!/bin/bash

echo "=== GitHub Search Test ==="

# Test 1: Check GitHub API rate limit
echo -e "\n1. Checking GitHub API rate limit..."
rate_info=$(gh api rate_limit 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ Success!"
    remaining=$(echo "$rate_info" | jq -r '.rate.remaining')
    reset=$(echo "$rate_info" | jq -r '.rate.reset')
    reset_time=$(date -d @$reset '+%Y-%m-%d %H:%M:%S')
    echo "   Remaining requests: $remaining"
    echo "   Reset time: $reset_time"
else
    echo "❌ Failed: $rate_info"
fi

# Test 2: Simple search for bounty issues
echo -e "\n2. Searching for bounty issues..."
test_query="label:bounty+type:issue+state:open"
echo "   Query: $test_query"

result=$(gh api "search/issues?q=$test_query" 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ Success!"
    count=$(echo "$result" | jq -r '.total_count')
    echo "   Issues found: $count"
    
    if [ "$count" -gt 0 ]; then
        echo -e "\n   Top 5 issues:"
        echo "$result" | jq -c '.items[0:5]'
    fi
else
    echo "❌ Failed: $result"
fi

# Test 3: Test with explicit payment keyword
echo -e "\n3. Searching for issues with explicit payment..."
test_query2="label:bounty+type:issue+state:open+$100"
echo "   Query: $test_query2"

result2=$(gh api "search/issues?q=$test_query2" 2>&1)
if [ $? -eq 0 ]; then
    echo "✅ Success!"
    count=$(echo "$result2" | jq -r '.total_count')
    echo "   Issues found: $count"
else
    echo "❌ Failed: $result2"
fi

echo -e "\n=== Test Completed ==="
