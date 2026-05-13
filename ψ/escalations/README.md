# Escalations

Tasks ที่ fail gate หรือ blocked ระหว่าง execution — รอ ธาม ตัดสินใจ

Format: `ESC-{task_id}_{reason}.md`

```markdown
## Escalation: TASK-XXX
**reason**: risk=HIGH / missing field / blocked on X
**gated_at**: ISO datetime
**waiting_for**: ธาม decision
**auto_rollback**: yes/no
```

Omega ต้อง cc ธาม ทันทีเมื่อสร้างไฟล์ใน dir นี้:
`maw talk-to tham "cc: BLOCKED — TASK-XXX escalated, see ψ/escalations/"`
