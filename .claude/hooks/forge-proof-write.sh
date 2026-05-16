#!/usr/bin/env bash
# forge-proof-write.sh — แปลง Omega proof → Forge evidence format → เขียนลง tools/logs/
# FIX: proof filename ใช้ _complete/_fail (ไม่ใช่ _OK/_FAILED)
# FIX: python3 สร้าง JSON ป้องกัน control char issues

# Args: $1 = task_id, $2 = result (OK|FAILED), $3 = summary, $4 = files_changed (optional)
TASK_ID="${1:-UNKNOWN}"
RESULT="${2:-FAILED}"
SUMMARY="${3:-no summary}"
FILES_CHANGED="${4:-none}"

LOGS_DIR="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/tools/logs"
LAST_BACKUP_FILE="/mnt/d/01 Main Work/Boots/Agentic AI/mission-control/tools/LAST_BACKUP_DIR.txt"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OUTBOX="/mnt/d/Git/omega-oracle/ψ/outbox"

mkdir -p "$LOGS_DIR"

LOG_FILE="$LOGS_DIR/omega_forge_${TASK_ID}_${TIMESTAMP}.log"
SUMMARY_FILE="$LOGS_DIR/forge_omega_${TIMESTAMP}.summary.json"

# ─── map RESULT → proof status ───────────────────────────────────────────────
# OK → complete, FAILED → fail  (ไม่ใช่ _OK / _FAILED ใน filename)
if [ "$RESULT" = "OK" ]; then
  PROOF_STATUS="complete"
else
  PROOF_STATUS="fail"
fi

PROOF_FILE="$OUTBOX/PROOF-forge-${TASK_ID}_${PROOF_STATUS}.json"

# ─── write run log ────────────────────────────────────────────────────────────

cat > "$LOG_FILE" <<LOGEOF
[$(date '+%H:%M:%S')] === OMEGA FORGE RUN LOG ===
TASK_ID=${TASK_ID}
RESULT=${RESULT}
SUMMARY=${SUMMARY}
FILES_CHANGED=${FILES_CHANGED}
TIMESTAMP=${TIMESTAMP}
LOGEOF

# ─── write summary JSON + proof via python3 (JSON-safe) ──────────────────────

TASK_ID="$TASK_ID" \
SUMMARY="$SUMMARY" \
FILES_CHANGED="$FILES_CHANGED" \
LOG_FILE="$LOG_FILE" \
RESULT="$RESULT" \
PROOF_STATUS="$PROOF_STATUS" \
TIMESTAMP="$TIMESTAMP" \
TIMESTAMP_ISO="$TIMESTAMP_ISO" \
SUMMARY_FILE="$SUMMARY_FILE" \
PROOF_FILE="$PROOF_FILE" \
python3 - <<'PYEOF'
import json, os

# Forge summary (Forge execution contract format)
summary = {
    "TASK_NAME": os.environ['TASK_ID'],
    "ACTION_TAKEN": os.environ['SUMMARY'],
    "FILES_CHANGED": os.environ['FILES_CHANGED'],
    "LOG_PATH": os.environ['LOG_FILE'],
    "RESULT": os.environ['RESULT'],
    "ROOT_CAUSE": "",
    "NEXT_ACTION": "update todo.md + memory writeback",
    "CLASSIFICATION": "DETERMINISTIC",
    "BACKUP_DIR": "",
    "AGENT": "omega",
    "TIMESTAMP": os.environ['TIMESTAMP']
}

with open(os.environ['SUMMARY_FILE'], "w", encoding="utf-8") as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)

# Omega proof (standard format — status = complete | fail)
proof = {
    "task_id": f"forge-{os.environ['TASK_ID']}",
    "status": os.environ['PROOF_STATUS'],
    "proof": os.environ['SUMMARY_FILE'],
    "summary": os.environ['SUMMARY'],
    "completed_at": os.environ['TIMESTAMP_ISO']
}

with open(os.environ['PROOF_FILE'], "w", encoding="utf-8") as f:
    json.dump(proof, f, ensure_ascii=False, indent=2)
PYEOF

# ─── อัพเดต LAST_BACKUP_DIR ──────────────────────────────────────────────────
LAST_BACKUP_DIR=$(dirname "$LAST_BACKUP_FILE")
[ -d "$LAST_BACKUP_DIR" ] && echo "$LOGS_DIR/omega_${TIMESTAMP}" > "$LAST_BACKUP_FILE"

echo "✅ Forge evidence written:"
echo "   Log:     $LOG_FILE"
echo "   Summary: $SUMMARY_FILE"
echo "   Proof:   $PROOF_FILE  (status=${PROOF_STATUS})"
