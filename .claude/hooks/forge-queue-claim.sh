#!/bin/bash
# forge-queue-claim.sh — อ่าน Forge todo.md → claim 1 task → สร้าง task contract ใน ψ/inbox/

TODO="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/todo.md"
INBOX="/mnt/d/Git/omega-oracle/ψ/inbox"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_TAG=$(date +"%Y%m%d_%H%M%S")

if [ ! -f "$TODO" ]; then
  echo "ERROR: todo.md not found at $TODO" >&2
  exit 1
fi

# หา task แรกที่ยัง [ ] และ STATUS=READY หรือ SFSR ที่ยังไม่เสร็จ
# รองรับ 2 format: SFSR block และ TASK_NAME block

# Format 1: SFSR block — "## [ ] SFSR NN"
SFSR_LINE=$(grep -n "^## \[ \] SFSR" "$TODO" | head -1)

# Format 2: TASK_NAME block — "- [ ] TASK_NAME="
TASK_LINE=$(grep -n "^- \[ \] TASK_NAME=" "$TODO" | head -1)

if [ -n "$SFSR_LINE" ]; then
  LINE_NUM=$(echo "$SFSR_LINE" | cut -d: -f1)
  SFSR_NUM=$(echo "$SFSR_LINE" | grep -oP 'SFSR \K[0-9]+')
  SFSR_TITLE=$(echo "$SFSR_LINE" | sed "s/.*SFSR ${SFSR_NUM} — //")
  TASK_DESC=$(sed -n "$((LINE_NUM+1))p" "$TODO" | sed 's/^- \[ \] //' | head -c 200)
  TASK_ID="SFSR-${SFSR_NUM}"
  TASK_WHAT="SFSR-${SFSR_NUM} ${SFSR_TITLE}: $TASK_DESC"
  TASK_RISK="medium"

elif [ -n "$TASK_LINE" ]; then
  LINE_NUM=$(echo "$TASK_LINE" | cut -d: -f1)
  TASK_NAME=$(echo "$TASK_LINE" | sed 's/.*TASK_NAME=//' | tr -d ' ')
  OWNER=$(sed -n "$((LINE_NUM+1))p" "$TODO" | sed 's/.*OWNER=//' | tr -d ' ')
  EXPECTED=$(sed -n "$((LINE_NUM+2))p" "$TODO" | sed 's/.*EXPECTED=//' | head -c 300)
  TASK_ID="$TASK_NAME"
  TASK_WHAT="$TASK_NAME — $EXPECTED"
  TASK_RISK="low"

else
  echo "NO_RUNNABLE_TASK: ไม่มี task ที่ claim ได้ใน todo.md" >&2
  exit 0
fi

# สร้าง task contract JSON
CONTRACT_FILE="$INBOX/TASK-forge-${DATE_TAG}_${TASK_ID}.json"

cat > "$CONTRACT_FILE" << JSONEOF
{
  "task_id": "forge-${DATE_TAG}",
  "forge_task": "$TASK_ID",
  "from": "forge-queue",
  "to": "omega",
  "what": "$TASK_WHAT",
  "how": "ทำตาม Forge execution contract — read memory → execute → evidence → writeback",
  "proof": "tools/logs/forge_omega_${DATE_TAG}.summary.json exists + RESULT=OK",
  "rollback": "ไม่มี state change ก่อนจะมี evidence — safe to retry",
  "risk": "$TASK_RISK",
  "forge_paths": {
    "todo": "$TODO",
    "logs": "/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/tools/logs",
    "memory": "/mnt/d/Obsidian/Memory/Marcuz/Projects/Marcuzx Forge V3/03 - Agent Memory/Tham/Tham - Master Memory.md"
  },
  "created_at": "$TIMESTAMP"
}
JSONEOF

echo "✅ Task claimed: $TASK_ID"
echo "📄 Contract: $CONTRACT_FILE"
