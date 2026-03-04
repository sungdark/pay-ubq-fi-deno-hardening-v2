#!/bin/bash

echo "=== GitHub API Test ==="

# Check if gh is installed
if ! command -v gh &>/dev/null; then
    echo "gh command not found"
    exit 1
fi

# Check auth status
echo -e "\n=== gh auth status ==="
gh auth status

# Test API access
echo -e "\n=== gh api user ==="
gh api user

echo -e "\n=== GitHub API Test Completed ==="
