#!/bin/bash
# force-rrr-at-80.sh — PostToolUse hook: เตือน 70%, บังคับ /rrr ที่ 80%

WARN_THRESHOLD=70
FORCE_THRESHOLD=80

STATUSLINE_JSON="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}/statusline-raw.json"
[ ! -f "$STATUSLINE_JSON" ] && exit 0

PCT=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f:
    d = json.load(f)
print(int(float(d.get('context_window',{}).get('used_percentage', 0))))
" 2>/dev/null)

[ -z "$PCT" ] && exit 0

FORCE_FLAG="/tmp/omega-rrr-forced-$(date +%Y%m%d-%H)"
if [ "$PCT" -ge "$FORCE_THRESHOLD" ] 2>/dev/null; then
  if [ ! -f "$FORCE_FLAG" ]; then
    touch "$FORCE_FLAG"
    cat >&2 << EOF

🚨 OMEGA CONTEXT ${PCT}% — STOP NOW 🚨
auto-compact เกิดที่ ~80% — retrospective จะหาย!

รัน:  /rrr   แล้ว  /forward
แล้ว cc ธาม: maw talk-to tham "cc: Omega — /rrr complete"

EOF
  fi
  exit 0
fi

WARN_FLAG="/tmp/omega-rrr-warn-$(date +%Y%m%d-%H%M | sed 's/.$//g')"
if [ "$PCT" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
  if [ ! -f "$WARN_FLAG" ]; then
    touch "$WARN_FLAG"
    cat >&2 << EOF

⚠️  Omega context ${PCT}% — เตรียม /rrr + /forward ก่อน compact

EOF
  fi
fi

exit 0
