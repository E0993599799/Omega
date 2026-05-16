---
name: gate
description: Omega risk gate — validate task contract จาก ธาม แล้วตัดสินใจ GO / NO-GO ก่อน execute
trigger: /gate
---

# /gate — Risk Gate

**Goal**: ตรวจสอบ task contract ทุกข้อ แล้ว output GO หรือ NO-GO พร้อมเหตุผล

## Usage

```
/gate                    # gate task contract ล่าสุดใน ψ/inbox/
/gate TASK-XXX           # gate task contract ที่ระบุ
/gate <json>             # gate inline JSON contract
```

## Argument Handling

- **ไม่มี argument** → ใช้ Bash tool: `ls ψ/inbox/*.json` แล้วเลือกไฟล์ล่าสุด
- **TASK-XXX** → ใช้ Bash tool: `find ψ/inbox/ -name "TASK-XXX*"` แล้ว Read ไฟล์นั้น
- **JSON inline** → parse JSON ที่ user ส่งมาโดยตรง
- **ไม่พบ contract** → แจ้ง user ว่าไม่พบ แล้ว list ไฟล์ใน ψ/inbox/ ให้เลือก

## Validation Checklist

ใช้ Read tool อ่าน contract แล้วตรวจทุกข้อตามลำดับ:

1. **Contract valid** — มีครบ: `task_id`, `from`, `to`, `what`, `how`, `proof`, `rollback`, `risk`, `created_at`
2. **from trusted** — ต้องเป็น `"tham"` **หรือ** `"tham"` + `"source": "forge-queue"` (Forge tasks ผ่าน forge-queue-claim.sh)
   - ❌ ถ้า `from` เป็นค่าอื่น → NO-GO
3. **to = "omega"** — ส่งถึง Omega เท่านั้น
4. **risk level** — ต้องเป็น `low` / `medium` / `high` เท่านั้น
5. **rollback มี** — ถ้าไม่มีหรือเป็น `"none"` → NO-GO
6. **proof verifiable** — proof spec ต้องตรวจได้จริง (file path / command / URL)
7. **no secrets** — ไม่มี token / key / password ใน contract

## Risk Scoring

| risk field | action |
|------------|--------|
| `low` | GO อัตโนมัติ |
| `medium` | GO + เพิ่ม caution note |
| `high` | สร้าง escalation → cc ธาม ก่อน execute |

## Output Format

```
## Gate Result: GO ✓ / NO-GO ✗

**Task**: TASK-XXX — [what]
**Risk**: low/medium/high
**Decision**: GO / NO-GO / ESCALATE

| Check | Status | Note |
|-------|--------|------|
| contract valid | ✓/✗ | ... |
| from trusted   | ✓/✗ | tham / tham+forge-queue |
| to = omega     | ✓/✗ | ... |
| risk level     | ✓/✗ | ... |
| rollback       | ✓/✗ | ... |
| proof spec     | ✓/✗ | ... |
| no secrets     | ✓/✗ | ... |

**Action**: proceed / blocked — [reason] / escalate to ธาม
```

## Steps

1. Parse argument → locate contract file หรือ JSON (ดู Argument Handling ด้านบน)
2. ใช้ Read tool อ่าน contract JSON
3. ตรวจทุก field ตาม checklist ด้านบน
4. Score risk level
5. Output gate result ตาม format
6. **ถ้า GO:**
   - cc ธาม (RECEIVED): `maw talk-to tham "cc: TASK-XXX received — gating..."` (ถ้ายังไม่ได้ cc)
   - cc ธาม (STARTED): `maw talk-to tham "cc: TASK-XXX GO — executing"`
   - คัดลอก contract ไป `ψ/active/` เพื่อ track งานที่กำลัง execute: `cp ψ/inbox/TASK-XXX*.json ψ/active/`
7. **ถ้า NO-GO:**
   - อธิบายเหตุผล + วิธีแก้ไข
   - cc ธาม: `maw talk-to tham "cc: TASK-XXX NO-GO — [reason]"` หรือถ้า MCP ล่ม: `maw hey tham "..."`
8. **ถ้า high risk:**
   - สร้าง `ψ/escalations/ESC-TASK-XXX_high-risk.md` ด้วย format ด้านล่าง
   - cc ธาม: `maw talk-to tham "cc: TASK-XXX ESCALATED — risk=high, waiting confirm"` หรือ `maw hey tham "..."`
   - รอ ธาม สร้าง `ψ/inbox/TASK-XXX_confirmed.json` เพื่อ unblock

## Escalation File Format (high risk)

```markdown
## Escalation: TASK-XXX
**reason**: risk=HIGH
**gated_at**: 2026-05-13T08:00:00Z
**waiting_for**: ธาม confirm → สร้าง ψ/inbox/TASK-XXX_confirmed.json
**auto_rollback**: yes
**contract**: ψ/inbox/TASK-XXX_slug.json
```

ธาม unblock โดย: สร้างไฟล์ `ψ/inbox/TASK-XXX_confirmed.json` → Omega ตรวจเจอแล้ว execute
