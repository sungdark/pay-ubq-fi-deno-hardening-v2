#!/bin/bash

# Test GitHub API response structure

echo "=== GitHub API Response Test ==="

# Try different ways to get data
for i in 1 2 3; do
    echo -e "\n--- Attempt $i ---"
    
    # Direct API call
    echo "1. Direct gh api call:"
    RESULT=$(gh api "search/issues?q=label:bounty+type:issue+state:open" 2>&1)
    echo "   Exit code: $?"
    if [ $? -eq 0 ]; then
        echo "   Response contains items: $(echo "$RESULT" | grep -o 'items' || echo "NO")"
        echo "   Length: $(echo -n "$RESULT" | wc -c)"
        echo "   First 200 chars:"
        echo "$RESULT" | head -c 200
        echo ""
    else
        echo "   Error: $RESULT"
    fi
    
    # Try with jq filtering
    echo -e "\n2. With jq filtering:"
    ITEMS=$(gh api "search/issues?q=label:bounty+type:issue+state:open" --jq '.items[0:2]' 2>&1)
    echo "   Exit code: $?"
    if [ $? -eq 0 ]; then
        echo "   Items count: $(echo "$ITEMS" | jq 'length' 2>&1 || echo "Error counting")"
        echo "   Response:"
        echo "$ITEMS"
    else
        echo "   Error: $ITEMS"
    fi
    
    sleep 2
done

echo -e "\n=== Complete ==="
