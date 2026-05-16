#!/usr/bin/env bash
# forge-queue-claim.sh — อ่าน Forge todo.md → claim 1 task → สร้าง task contract ใน ψ/inbox/
# FIX: from = "tham" (source = "forge-queue") — gate requires from = "tham"
# FIX: python3 + env vars สร้าง JSON ป้องกัน invalid control characters

set -euo pipefail

TODO="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/todo.md"
INBOX="/mnt/d/Git/omega-oracle/ψ/inbox"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_TAG=$(date +"%Y%m%d_%H%M%S")
LOGS="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/tools/logs"
MEMORY="/mnt/d/Obsidian/Memory/Marcuz/Projects/Marcuzx Forge V3/03 - Agent Memory/Tham/Tham - Master Memory.md"

if [ ! -f "$TODO" ]; then
  echo "ERROR: todo.md not found at $TODO" >&2
  exit 1
fi

# ─── parse todo.md ───────────────────────────────────────────────────────────

SFSR_LINE=$(grep -n "^## \[ \] SFSR" "$TODO" 2>/dev/null | head -1 || echo "")
TASK_LINE=$(grep -n "^- \[ \] TASK_NAME=" "$TODO" 2>/dev/null | head -1 || echo "")

if [ -n "$SFSR_LINE" ]; then
  SFSR_NUM=$(echo "$SFSR_LINE" | grep -oP 'SFSR \K[0-9]+' || echo "00")
  SFSR_TITLE=$(echo "$SFSR_LINE" | sed "s/.*SFSR ${SFSR_NUM}[^a-zA-Z]*//" | head -c 150)
  TASK_ID="SFSR-${SFSR_NUM}"
  TASK_WHAT="SFSR-${SFSR_NUM} ${SFSR_TITLE}"
  TASK_RISK="medium"

elif [ -n "$TASK_LINE" ]; then
  LINE_NUM=$(echo "$TASK_LINE" | cut -d: -f1)
  TASK_NAME=$(echo "$TASK_LINE" | sed 's/.*TASK_NAME=//' | tr -d ' ')
  EXPECTED=$(sed -n "$((LINE_NUM+2))p" "$TODO" 2>/dev/null | sed 's/.*EXPECTED=//' | head -c 200 || echo "")
  TASK_ID="$TASK_NAME"
  TASK_WHAT="${TASK_NAME}: ${EXPECTED}"
  TASK_RISK="low"

else
  echo "NO_RUNNABLE_TASK: ไม่มี task ที่ claim ได้ใน todo.md" >&2
  exit 0
fi

# ─── duplicate guard ─────────────────────────────────────────────────────────

EXISTING=$(find "$INBOX" -name "TASK-forge-*${TASK_ID}*.json" 2>/dev/null | head -1 || echo "")
if [ -n "$EXISTING" ]; then
  echo "SKIP: $TASK_ID already claimed → $EXISTING" >&2
  exit 0
fi

# ─── write contract via python3 (JSON-safe, vars passed as env) ──────────────

CONTRACT_FILE="$INBOX/TASK-forge-${DATE_TAG}_${TASK_ID}.json"

CONTRACT_FILE="$CONTRACT_FILE" \
TASK_ID="$TASK_ID" \
DATE_TAG="$DATE_TAG" \
TASK_WHAT="$TASK_WHAT" \
TASK_RISK="$TASK_RISK" \
TIMESTAMP="$TIMESTAMP" \
TODO="$TODO" \
LOGS="$LOGS" \
MEMORY="$MEMORY" \
python3 - <<'PYEOF'
import json, os

contract = {
    "task_id": f"forge-{os.environ['DATE_TAG']}",
    "forge_task": os.environ['TASK_ID'],
    "from": "tham",
    "source": "forge-queue",
    "to": "omega",
    "what": os.environ['TASK_WHAT'],
    "how": "ทำตาม Forge execution contract — read memory → execute → evidence → writeback",
    "proof": f"tools/logs/forge_omega_{os.environ['DATE_TAG']}.summary.json exists + RESULT=OK",
    "rollback": "ไม่มี state change ก่อนจะมี evidence — safe to retry",
    "risk": os.environ['TASK_RISK'],
    "forge_paths": {
        "todo": os.environ['TODO'],
        "logs": os.environ['LOGS'],
        "memory": os.environ['MEMORY']
    },
    "created_at": os.environ['TIMESTAMP']
}

with open(os.environ['CONTRACT_FILE'], "w", encoding="utf-8") as f:
    json.dump(contract, f, ensure_ascii=False, indent=2)

print(f"✅ Task claimed: {contract['forge_task']}")
print(f"   from: {contract['from']} (source: {contract['source']})")
print(f"   contract: {os.environ['CONTRACT_FILE']}")
PYEOF
