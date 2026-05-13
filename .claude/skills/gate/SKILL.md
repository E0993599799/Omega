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
/gate <task_id>          # gate task contract ที่ระบุ
/gate <json>             # gate inline JSON contract
```

## Validation Checklist

ตรวจทุกข้อตามลำดับ:

1. **Contract valid** — มีทุก field: `task_id`, `from`, `to`, `what`, `how`, `proof`, `rollback`, `risk`, `created_at`
2. **from = "tham"** — รับเฉพาะจาก ธาม
3. **to = "omega"** — ส่งถึง Omega เท่านั้น
4. **risk level** — low / medium / high
5. **rollback มี** — ถ้าไม่มี = NO-GO
6. **proof verifiable** — proof spec ต้องตรวจได้จริง
7. **no secrets** — ห้ามมี token / key ใน contract

## Risk Scoring

| risk field | action |
|------------|--------|
| `low` | GO อัตโนมัติ |
| `medium` | GO + เพิ่ม caution note |
| `high` | รายงาน ธาม ก่อน execute — รอ confirm |

## Output Format

```
## Gate Result: [GO ✓ / NO-GO ✗]

**Task**: TASK-XXX
**Risk**: low/medium/high
**Decision**: ...

| Check | Status | Note |
|-------|--------|------|
| contract valid | ✓/✗ | ... |
| from = tham    | ✓/✗ | ... |
...

**Action**: [proceed / blocked / escalate to ธาม]
```

## Steps

1. อ่าน contract จาก ψ/inbox/ หรือ argument
2. ตรวจทุก field ตาม checklist
3. Score risk
4. Output gate result
5. ถ้า GO → บอก Omega พร้อม execute
6. ถ้า NO-GO → อธิบายเหตุผล + วิธีแก้ไข
7. ถ้า high risk → draft message สำหรับ cc ธาม
