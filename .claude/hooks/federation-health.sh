#!/bin/bash
# federation-health.sh — ตรวจสอบ federation status แล้วแจ้ง ธาม ถ้า offline

LOCK="/tmp/omega-fed-health.lock"
if [ -f "$LOCK" ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) ))
  [ "$AGE" -lt 1800 ] && exit 0
fi
touch "$LOCK"

STATUS=$(maw federation status 2>/dev/null)
PEERS=$(echo "$STATUS" | grep -c "●" 2>/dev/null); PEERS=${PEERS:-0}
OFFLINE=$(echo "$STATUS" | grep -c "offline" 2>/dev/null); OFFLINE=${OFFLINE:-0}

if [ "$OFFLINE" -gt 0 ]; then
  MAW_BIN="/root/.bun/bin/maw"
  MSG="alert: Omega federation health — $OFFLINE peer(s) offline. Run: maw federation status"
  [ -f "$MAW_BIN" ] && "$MAW_BIN" hey tham "$MSG" &>/dev/null &
  echo "⚠️  Federation: $OFFLINE peer(s) offline — alerted ธาม" >&2
fi

exit 0
