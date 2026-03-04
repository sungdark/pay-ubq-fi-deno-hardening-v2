#!/bin/bash

# Bounty Notifier - Sends notifications when bounties are found

LOG_FILE="/root/.openclaw/workspace/logs/bounty_scout_fast.log"
NOTIFICATION_FILE="/root/.openclaw/workspace/logs/bounty_notifications.log"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found: $LOG_FILE" >&2
    exit 1
fi

# Get the last 15 minutes of log entries
FIFTEEN_MINUTES_AGO=$(date -d "15 minutes ago" +"%Y-%m-%d %H:%M:%S")
LAST_RUN=$(grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' "$LOG_FILE" | tail -1)

# If no run detected in last 15 minutes
if [ -z "$LAST_RUN" ] || [ "$(date -d "$LAST_RUN" +%s)" -lt "$(date -d "$FIFTEEN_MINUTES_AGO" +%s)" ]; then
    exit 0
fi

# Check for found bounties
BOUNTIES_FOUND=$(grep -E '\[[^]]*\{[^}]*\}[^]]*\]' "$LOG_FILE" | tail -1 | grep -o '\{[^}]*\}')

if [ -n "$BOUNTIES_FOUND" ]; then
    # Log the notification
    echo "$(date +"%Y-%m-%d %H:%M:%S") - Bounties found: $BOUNTIES_FOUND" >> "$NOTIFICATION_FILE"
    
    # Send a simple notification (this could be extended to use Telegram/Signal/email)
    echo "✅ Bounty opportunity scout found new tasks!"
    echo "📅 Last check: $LAST_RUN"
    echo "💎 Tasks found: $(echo "$BOUNTIES_FOUND" | jq -r '. | length')"
    echo "$BOUNTIES_FOUND"
else
    echo "ℹ️ No bounties found in last 15 minutes"
fi
