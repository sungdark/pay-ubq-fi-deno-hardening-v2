#!/bin/bash

# Bounty Scout Configuration

# Log directory
LOG_DIR="/root/.openclaw/workspace/logs"
mkdir -p "$LOG_DIR"

# Log file
LOG_FILE="$LOG_DIR/bounty_scout_cron.log"

# Notification file
NOTIFICATION_FILE="$LOG_DIR/bounty_notifications_cron.log"

# Report file (daily)
REPORT_FILE="/root/.openclaw/workspace/战报_$(date +"%H00").txt"

# GitHub API rate limits
RATE_LIMIT=5000
RATE_RESET=$(gh api rate_limit --jq '.rate.reset')
RATE_REMAINING=$(gh api rate_limit --jq '.rate.remaining')

# Search parameters
SEARCH_QUERIES=(
    "label:bounty+type:issue+state:open"
    "label:reward+type:issue+state:open"
    'label:"help wanted"+type:issue+state:open'
)

# Search timeout
SEARCH_TIMEOUT=30

# Sleep time between searches
SEARCH_DELAY=2

# Task execution timeout
EXECUTION_TIMEOUT=600

# Task execution delay between tasks
EXECUTION_DELAY=5

# Reward types to include
INCLUDE_REWARD_TYPES=("monetary" "token" "nft")

# Reward minimums (in USD)
MINIMUM_REWARD=10

# Excluded users/organizations
EXCLUDED_OWNERS=("")

# Excluded repositories
EXCLUDED_REPOSITORIES=("")

# Excluded labels
EXCLUDED_LABELS=("good first issue")

# Language preferences
LANGUAGE_PREFERENCES=("Python" "JavaScript" "TypeScript" "Rust" "Go" "Java")
