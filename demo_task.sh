#!/bin/bash

# Demo Task Execution Script

set -e

# Configuration
TASK_ID="demo-task-1"
WORKSPACE="/root/.openclaw/workspace"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Main function
main() {
    log "Starting demo task execution..."
    
    log "Step 1: Checking GitHub CLI access..."
    if ! gh auth status &>/dev/null; then
        log "ERROR: GitHub CLI not authenticated"
        exit 1
    fi
    log "✅ GitHub CLI authenticated successfully"
    
    log "Step 2: Creating demo task file..."
    cat > "$WORKSPACE/demo_task_$TASK_ID.txt" <<EOF
# Demo Task Report - Task $TASK_ID

## Task Overview
- Task ID: $TASK_ID
- Task Type: Demo Task
- Status: Completed
- Priority: Low
- Created: $(date '+%Y-%m-%d %H:%M:%S')
- Completed: $(date '+%Y-%m-%d %H:%M:%S')

## Task Description
This demo task demonstrates the task execution process in OpenClaw. It is a simple task that creates a report file.

## Task Steps
1. Checked GitHub CLI access
2. Created demo task file
3. Verified task file creation

## Task Results
The task has been completed successfully.

EOF
    log "✅ Demo task file created successfully"
    
    log "Step 3: Adding task file to git..."
    cd "$WORKSPACE"
    git add "demo_task_$TASK_ID.txt"
    log "✅ Task file added to git"
    
    log "Step 4: Committing task file..."
    git commit -m "Add demo task report for $TASK_ID"
    log "✅ Task file committed successfully"
    
    log "Step 5: Pushing commit..."
    git remote -v
    git push origin main
    log "✅ Commit pushed successfully"
    
    log "Demo task execution completed successfully!"
}

# Main entry point
main
