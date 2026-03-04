#!/usr/bin/env bash
set -euo pipefail
now=$(date -u "+%Y-%m-%d %H:%M UTC")
echo "[$now] bounty-opportunity-scout"
echo

echo "Permission gate (must check in order, continue if any one passes):"
if gh auth status >/tmp/gh_auth_status.txt 2>&1; then
  auth_ok=1; echo "1) gh auth status: OK"
else
  auth_ok=0; echo "1) gh auth status: FAIL"
  sed -n "1,5p" /tmp/gh_auth_status.txt || true
fi

issue_repo="Scottcjn/rustchain-bounties"
issue_num=433
probe_body="bounty-scout permission probe $(date -u "+%Y-%m-%dT%H:%M:%SZ")"
comment_ok=0
if out=$(gh api -X POST "repos/$issue_repo/issues/$issue_num/comments" -f body="$probe_body" 2>/tmp/gh_comment_err.txt); then
  comment_id=$(printf "%s" "$out" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id", ""))')
  if [ -n "$comment_id" ]; then
    gh api -X DELETE "repos/$issue_repo/issues/comments/$comment_id" >/dev/null 2>&1 || true
    comment_ok=1
    echo "2) issue comment capability: OK (post+delete probe on $issue_repo#$issue_num)"
  fi
fi
if [ "$comment_ok" -ne 1 ]; then
  echo "2) issue comment capability: FAIL"
  sed -n "1,4p" /tmp/gh_comment_err.txt || true
fi

fork_repo="sungdark/rustchain-bounties"
branch="probe/bounty-scout-$(date -u "+%Y%m%d%H%M%S")"
push_ok=0
work=$(mktemp -d)
if git clone --quiet "https://github.com/$fork_repo.git" "$work/repo" 2>/tmp/git_clone_err.txt; then
  cd "$work/repo"
  git checkout -q -b "$branch"
  git config user.name "openclaw-bot"
  git config user.email "openclaw-bot@users.noreply.github.com"
  echo "probe $(date -u "+%Y-%m-%dT%H:%M:%SZ")" > .bounty_scout_probe
  git add .bounty_scout_probe
  git commit -q -m "chore: permission probe"
  if git push -q origin "$branch" >/tmp/git_push_out.txt 2>/tmp/git_push_err.txt; then
    push_ok=1
    git push -q origin --delete "$branch" >/dev/null 2>&1 || true
    echo "3) fork push capability: OK (temp branch push/delete on $fork_repo)"
  else
    echo "3) fork push capability: FAIL"
    sed -n "1,4p" /tmp/git_push_err.txt || true
  fi
else
  echo "3) fork push capability: FAIL (clone)"
  sed -n "1,4p" /tmp/git_clone_err.txt || true
fi

if [ $((auth_ok + comment_ok + push_ok)) -ge 1 ]; then
  rule="CONTINUE"
else
  rule="STOP"
fi

echo "=> Rule result: $rule (any-of 1/2/3)"
if [ "$rule" = "STOP" ]; then
  exit 0
fi

echo
echo "Scan scope:"
echo "- Global GitHub issues search via gh api /search/issues (sorted by updated)"
echo "- Query: is:open is:issue archived:false (bounty OR reward OR \"help wanted\")"
echo "- Prioritized explicit reward + clear settlement path"

query='is:open archived:false (bounty OR reward OR "help wanted")'
q_enc='is:open+archived:false+(bounty+OR+reward+OR+"help+wanted")'
gh api "search/issues?q=${q_enc}&sort=updated&order=desc&per_page=100" > /tmp/bounty_search_raw.json

python3 - <<'PY'
import json,re
raw=json.load(open('/tmp/bounty_search_raw.json'))
items=raw.get('items',[])
pat=re.compile(r'(\$\s?\d[\d,]*|\b\d+[\d,]*\s?(?:USD|USDT|USDC|XTZ|ETH|BTC)\b|\b(?:reward|bounty)\b.{0,30}\d)',re.I)
blocked=re.compile(r'japan|tokyo|osaka|jp\b|japanese',re.I)
res=[]
for it in items:
    t=(it.get('title') or '')+'\n'+(it.get('body') or '')
    repo=(it.get('repository_url') or '').split('/repos/')[-1] or 'unknown/unknown'
    if blocked.search((repo+' '+t).lower()):
        continue
    if pat.search(t):
        it['_repo']=repo
        res.append(it)
print('Notable explicit-reward hits seen this cycle:')
if not res:
    print('- none')
else:
    for it in res[:8]:
        repo=it.get('_repo','unknown/unknown')
        num=it.get('number')
        txt=((it.get('title') or '')+' '+(it.get('body') or ''))
        m=pat.search(txt)
        amt=m.group(0) if m else 'reward-mentioned'
        print(f'- {repo}#{num} ({amt})')
code_kw=re.compile(r'fix|bug|implement|add|refactor|test|ci|script|code|pr',re.I)
settle_kw=re.compile(r'paid|payment|payout|claim|on merge|after merge|invoice|escrow|issue bounty|label',re.I)
selected=[]
for it in res:
    txt=((it.get('title') or '')+'\n'+(it.get('body') or ''))
    if code_kw.search(txt) and settle_kw.search(txt):
        selected.append(it)
print('\nDecision:')
if not selected:
    print('- No new unclaimed low-friction CODE bounty with clear near-term in-repo settlement path was selected for immediate fork-first execution this cycle.')
else:
    it=selected[0]
    repo=it.get('_repo','unknown/unknown')
    print(f'- Selected for execution: {repo}#{it.get("number")} {it.get("url")}')
PY