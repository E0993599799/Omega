#!/usr/bin/env bash
# Detect quota/rate-limit errors in Claude Code tool output, trigger provider rotation

set -euo pipefail

STDIN_DATA=$(cat)
AI_SWITCH="/mnt/d/Git/omega-oracle/scripts/ai-switch.sh"
LOCK_FILE="/tmp/omega-quota-switch.lock"
STATE_FILE="/tmp/omega-ai-provider-state.json"

# Parse tool result for quota/rate-limit signals
QUOTA_HIT=$(echo "$STDIN_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    output = str(data)
    signals = ['rate_limit', 'quota_exceeded', 'overloaded', 'overload',
               '429', '529', 'insufficient_quota', 'RateLimitError',
               'credit balance is too low', 'quota has been exceeded']
    if any(s.lower() in output.lower() for s in signals):
        print('yes')
    else:
        print('no')
except Exception:
    print('no')
" 2>/dev/null || echo "no")

if [[ "$QUOTA_HIT" != "yes" ]]; then
  exit 0
fi

# Debounce — only switch once per 5 minutes
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
  if [[ $LOCK_AGE -lt 300 ]]; then
    exit 0
  fi
fi
touch "$LOCK_FILE"

CURRENT=$(python3 -c "
import json
try:
    d = json.load(open('$STATE_FILE'))
    print(d.get('active', 'claude-primary'))
except:
    print('claude-primary')
" 2>/dev/null || echo "claude-primary")

echo "[quota-detect] Rate limit detected on $CURRENT — rotating provider..." >&2

if [[ -x "$AI_SWITCH" ]]; then
  NEXT=$("$AI_SWITCH" next 2>/dev/null || echo "")
  if [[ -n "$NEXT" ]]; then
    echo "[quota-detect] Switched to: $NEXT" >&2
    # cc ธาม
    maw hey tham "cc: Omega — quota hit on $CURRENT, rotated to $NEXT" 2>/dev/null || true
  fi
fi
