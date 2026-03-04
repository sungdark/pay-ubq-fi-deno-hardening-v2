#!/bin/bash

# Test Bounty Scout Script

echo "=== Bounty Scout Test ==="

# Check if script is executable
if [ ! -x /root/.openclaw/workspace/bounty_scout_cron.sh ]; then
    echo "Script not executable. Running chmod +x..."
    chmod +x /root/.openclaw/workspace/bounty_scout_cron.sh
fi

# Clean up previous test data
rm -f /root/.openclaw/workspace/test_bounty_*.txt

# Test script
echo -e "\n=== Running Bounty Scout ==="
/root/.openclaw/workspace/bounty_scout_cron.sh

# Check results
echo -e "\n=== Checking Results ==="

# Check if any tasks were found
if grep -q "Bounty opportunity scout found new tasks!" /root/.openclaw/workspace/logs/bounty_scout_cron.log; then
    echo "✅ Tasks found!"
    echo -e "\n=== Log File ==="
    tail -20 /root/.openclaw/workspace/logs/bounty_scout_cron.log
else
    echo "ℹ️ No tasks found"
    echo -e "\n=== Log File ==="
    tail -20 /root/.openclaw/workspace/logs/bounty_scout_cron.log
fi

# Check if any reports were generated
REPORT_FILE=$(ls -1 /root/.openclaw/workspace/战报_*.txt 2>/dev/null | sort | head -1)

if [ -f "$REPORT_FILE" ]; then
    echo -e "\n=== Report File ==="
    head -50 "$REPORT_FILE"
else
    echo -e "\n=== No Report File Generated ==="
fi

echo -e "\n=== Test Completed ==="
