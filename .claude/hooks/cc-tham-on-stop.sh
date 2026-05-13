#!/bin/bash
# cc-tham-on-stop.sh — Stop hook: cc ธาม + เตือน /forward

LOCK_FILE="/tmp/cc-tham-omega.lock"
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt 60 ]; then
    exit 0
  fi
fi
touch "$LOCK_FILE"

RECENT_COMMIT=$(git -C /mnt/d/Git/omega-oracle log --oneline --since="5 minutes ago" -1 2>/dev/null)
STAGED=$(git -C /mnt/d/Git/omega-oracle diff --cached --name-only 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')
CHANGED=$(git -C /mnt/d/Git/omega-oracle diff --name-only HEAD 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')

if [ -n "$RECENT_COMMIT" ]; then
  SUMMARY="committed: $RECENT_COMMIT"
elif [ -n "$STAGED" ]; then
  SUMMARY="staged: $STAGED"
elif [ -n "$CHANGED" ]; then
  SUMMARY="modified: $CHANGED"
else
  SUMMARY="session ended — no changes"
fi

MAW_BIN="/root/.bun/bin/maw"
if [ -f "$MAW_BIN" ]; then
  "$MAW_BIN" hey tham "cc: Omega — ${SUMMARY}" &>/dev/null &
fi

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "✅ Auto CC'd ธาม — Omega: ${SUMMARY}" >&2
echo "" >&2
echo "⚠️  /forward แล้วหรือยัง?" >&2
echo "   ถ้ายัง: /rrr แล้ว /forward" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
