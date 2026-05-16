---
name: proof
description: Omega proof writer — verify งานเสร็จจริง แล้วเขียน proof file ลง ψ/outbox/
trigger: /proof
---

# /proof — Verify & Write Proof

**Goal**: ตรวจหลักฐานว่างานเสร็จจริง แล้วเขียน proof JSON ลง ψ/outbox/ และ archive contract

## Usage

```
/proof                        # proof สำหรับ task ที่ active อยู่ (ดูจาก ψ/active/)
/proof TASK-XXX               # proof สำหรับ task ที่ระบุ (default: complete)
/proof TASK-XXX fail          # proof สถานะ fail
/proof TASK-XXX blocked       # proof สถานะ blocked
```

## Argument Handling

- **ไม่มี argument** → ใช้ Bash: `ls ψ/active/*.json` หาไฟล์ที่กำลัง active
- **TASK-XXX** → ใช้ Bash: `find ψ/inbox/ ψ/active/ -name "TASK-XXX*"` อ่าน contract
- **TASK-XXX fail/blocked** → ใช้ status ที่ระบุ
- **ไม่พบ task** → แสดง list ψ/inbox/ + ψ/active/ ให้เลือก

## Verification Decision Tree

ใช้ Read หรือ Bash ตาม proof spec:

| proof spec มี | ใช้ tool | ตรวจอะไร |
|--------------|---------|---------|
| file path | Read tool | ไฟล์มีอยู่ + content ถูกต้อง |
| commit hash/message | Bash: `git log --oneline -5` | commit มีจริงใน git history |
| command output | Bash: รันคำสั่งนั้น | output ตรงกับ spec |
| GitHub URL | Bash: `gh api ...` | issue/PR มีจริง |
| directory structure | Bash: `find ... -type d` | ครบตาม spec |

**ถ้า rollback ยังทำไม่ได้** → เปลี่ยน status เป็น `blocked` แทน `complete`

## Verification Checklist

1. ใช้ Read tool อ่าน `ψ/inbox/TASK-XXX*.json` หรือ `ψ/active/TASK-XXX*.json` — ดู `proof` field
2. ตรวจ artifact ตาม decision tree ด้านบน
3. ตรวจ rollback path ยังเป็นไปได้ไหม
4. ตรวจว่าไม่มี secret รั่วใน output

**ห้ามเขียน proof ก่อนตรวจครบทุกข้อ**

## Proof File Format

ใช้ Write tool บันทึกที่ `ψ/outbox/PROOF-{task_id}_{status}.json`:

```json
{
  "task_id": "TASK-XXX",
  "status": "complete | fail | blocked",
  "proof": "หลักฐาน — file path / git log line / command output / URL",
  "summary": "สรุปสั้นๆ ภาษาไทย",
  "completed_at": "2026-05-13T08:00:00Z"
}
```

## Steps

1. Parse argument → locate task (ดู Argument Handling)
2. ใช้ Read tool อ่าน contract — ดู `proof` field
3. ตรวจ artifact ตาม decision tree
4. ตรวจ rollback path
5. ใช้ Write tool เขียน proof JSON ลง `ψ/outbox/`
6. **Archive contract** — ย้าย contract ออกจาก inbox/active ไป archive:
   ```bash
   mv ψ/active/TASK-XXX*.json ψ/archive/ 2>/dev/null || true
   mv ψ/inbox/TASK-XXX*.json ψ/archive/ 2>/dev/null || true
   ```
7. แสดง proof content + verification summary
8. cc ธาม (COMPLETE): `maw talk-to tham "cc: TASK-XXX proof ready — ψ/outbox/PROOF-TASK-XXX_complete.json"`
   - ถ้า MCP ล่ม: `maw hey tham "cc: TASK-XXX proof ready — [status]"`

## Example Output

```
## Proof: TASK-XXX — complete ✓

**Artifact verified**: ψ/outbox/PROOF-TASK-XXX_complete.json exists
**Git evidence**: abc1234 feat: TASK-XXX — [description]
**Rollback**: ยังทำได้ (rm ψ/outbox/PROOF-TASK-XXX_complete.json)
**Archived**: ψ/archive/TASK-XXX_slug.json

Proof written to: ψ/outbox/PROOF-TASK-XXX_complete.json
```
