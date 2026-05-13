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
2. **from = "tham"** — รับเฉพาะจาก ธาม
3. **to = "omega"** — ส่งถึง Omega เท่านั้น
4. **risk level** — ต้องเป็น low / medium / high เท่านั้น
5. **rollback มี** — ถ้าไม่มีหรือเป็น "none" = NO-GO
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
| from = tham    | ✓/✗ | ... |
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
6. **ถ้า GO** → แจ้ง Omega พร้อม execute + cc ธาม: `maw talk-to tham "cc: TASK-XXX gated GO — executing"`
7. **ถ้า NO-GO** → อธิบายเหตุผล + วิธีแก้ไข + cc ธาม: `maw talk-to tham "cc: TASK-XXX NO-GO — [reason]"`
8. **ถ้า high risk** → สร้าง `ψ/escalations/ESC-TASK-XXX_high-risk.md` แล้ว cc ธาม รอ confirm
