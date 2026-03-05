#!/bin/bash

# Simple test to check if we can find bounty issues

echo "Checking GitHub authentication..."
gh auth status

echo "Testing issue search with label:bounty..."
gh issue list --limit 10 --label "bounty" 2>&1
