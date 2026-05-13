#!/bin/bash
# forge-proof-write.sh — แปลง Omega proof → Forge evidence format → เขียนลง tools/logs/

# Args: $1 = task_id, $2 = result (OK|FAILED), $3 = summary, $4 = files_changed (optional)
TASK_ID="${1:-UNKNOWN}"
RESULT="${2:-FAILED}"
SUMMARY="${3:-no summary}"
FILES_CHANGED="${4:-none}"

LOGS_DIR="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/tools/logs"
LAST_BACKUP="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/tools/LAST_BACKUP_DIR.txt"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTBOX="/mnt/d/Git/omega-oracle/ψ/outbox"

mkdir -p "$LOGS_DIR"

LOG_FILE="$LOGS_DIR/omega_forge_${TASK_ID}_${TIMESTAMP}.log"
SUMMARY_FILE="$LOGS_DIR/forge_omega_${TIMESTAMP}.summary.json"

# เขียน run log
cat > "$LOG_FILE" << LOGEOF
[$(date '+%H:%M:%S')] === OMEGA FORGE RUN LOG ===
TASK_ID=$TASK_ID
RESULT=$RESULT
SUMMARY=$SUMMARY
FILES_CHANGED=$FILES_CHANGED
TIMESTAMP=$TIMESTAMP
LOGEOF

# เขียน summary JSON (Forge execution contract format)
cat > "$SUMMARY_FILE" << JSONEOF
{
  "TASK_NAME": "$TASK_ID",
  "ACTION_TAKEN": "$SUMMARY",
  "FILES_CHANGED": "$FILES_CHANGED",
  "LOG_PATH": "$LOG_FILE",
  "RESULT": "$RESULT",
  "ROOT_CAUSE": "",
  "NEXT_ACTION": "update todo.md + memory writeback",
  "CLASSIFICATION": "DETERMINISTIC",
  "BACKUP_DIR": "",
  "AGENT": "omega",
  "TIMESTAMP": "$TIMESTAMP"
}
JSONEOF

# อัพเดต LAST_BACKUP_DIR.txt
echo "$LOGS_DIR/omega_${TIMESTAMP}" > "$LAST_BACKUP"

# เขียน proof กลับ Omega outbox ด้วย
PROOF_FILE="$OUTBOX/PROOF-forge-${TASK_ID}_${RESULT}.json"
cat > "$PROOF_FILE" << PROOFEOF
{
  "task_id": "forge-$TASK_ID",
  "status": "$(echo $RESULT | tr '[:upper:]' '[:lower:]' | sed 's/ok/complete/' | sed 's/failed/fail/')",
  "proof": "$SUMMARY_FILE",
  "summary": "$SUMMARY",
  "completed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
PROOFEOF

echo "✅ Forge evidence written:"
echo "   Log:     $LOG_FILE"
echo "   Summary: $SUMMARY_FILE"
echo "   Proof:   $PROOF_FILE"
