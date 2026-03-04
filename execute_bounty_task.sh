#!/bin/bash

# Execute Bounty Task - Handles task execution and PR submission

# Usage: ./execute_bounty_task.sh <owner> <repo> <issue_number> <branch_name> <commit_message>

set -e

if [ $# -lt 5 ]; then
    echo "Usage: $0 <owner> <repo> <issue_number> <branch_name> <commit_message>" >&2
    exit 1
fi

OWNER="$1"
REPO="$2"
ISSUE_NUMBER="$3"
BRANCH_NAME="$4"
COMMIT_MESSAGE="$5"

# Check if repo exists locally
if [ ! -d "$REPO" ]; then
    # Check if we have a fork of the repo
    if gh repo view "$(gh auth status --json login -q .login)/$REPO" &>/dev/null; then
        git clone "https://github.com/$(gh auth status --json login -q .login)/$REPO.git"
        cd "$REPO"
        git remote add upstream "https://github.com/$OWNER/$REPO.git"
    else
        # Fork the repo
        gh repo fork "$OWNER/$REPO" --clone=true
        cd "$REPO"
        git remote add upstream "https://github.com/$OWNER/$REPO.git"
    fi
else
    cd "$REPO"
    git checkout main
    git pull upstream main
    git push origin main
fi

# Create a new branch
git checkout -b "$BRANCH_NAME"

# TODO: Add task implementation here
# For example:
# - Fix a bug
# - Implement a feature
# - Add documentation

# Commit and push changes
git add .
git commit -m "$COMMIT_MESSAGE"
git push origin "$BRANCH_NAME"

# Create PR
gh pr create --base "$OWNER:main" --head "$(gh auth status --json login -q .login):$BRANCH_NAME" --title "$COMMIT_MESSAGE" --body "Closes #$ISSUE_NUMBER"

echo "✅ PR created successfully: https://github.com/$OWNER/$REPO/pulls"
