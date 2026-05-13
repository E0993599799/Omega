---
name: proof
description: Omega proof writer — verify งานเสร็จจริง แล้วเขียน proof file ลง ψ/outbox/
trigger: /proof
---

# /proof — Verify & Write Proof

**Goal**: ตรวจหลักฐานว่างานเสร็จจริง แล้วเขียน proof JSON ลง ψ/outbox/

## Usage

```
/proof                   # เขียน proof สำหรับ task ที่กำลัง active
/proof <task_id>         # เขียน proof สำหรับ task ที่ระบุ
/proof <task_id> fail    # เขียน proof สถานะ fail
/proof <task_id> blocked # เขียน proof สถานะ blocked
```

## Verification Steps

ก่อนเขียน proof ต้องตรวจ:

1. **proof spec ตรง** — อ่าน `proof` field จาก task contract
2. **artifact มีจริง** — ไฟล์มี / commit มี / output ถูกต้อง
3. **ไม่มี secret รั่ว** — ไม่มี key / token ใน output
4. **rollback ยังทำได้** — ตรวจว่า rollback path ยังเป็นไปได้

**ห้ามเขียน proof ก่อนตรวจครบทุกข้อ**

## Proof File Format

บันทึกที่ `ψ/outbox/PROOF-{task_id}_{status}.json`:

```json
{
  "task_id": "TASK-XXX",
  "status": "complete | fail | blocked",
  "proof": "หลักฐาน (URL, file path, command output)",
  "summary": "สรุปสั้นๆ ภาษาไทย",
  "completed_at": "ISO datetime"
}
```

## Steps

1. อ่าน task contract จาก ψ/inbox/TASK-XXX*.json
2. ตรวจ proof spec ว่าต้องการหลักฐานอะไร
3. verify artifact มีจริง (ls / git log / cat output)
4. เขียน proof JSON ลง ψ/outbox/
5. แสดง proof content ให้ verify
6. Draft cc message สำหรับรายงาน ธาม:
   `maw talk-to tham "proof ready: TASK-XXX — [status]"`
