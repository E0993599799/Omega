# Handoff

Context ที่ ธาม ส่งมาให้ Omega สำหรับ session ถัดไป

Format: `HANDOFF-{date}_{slug}.md`

Omega ต้องอ่านไฟล์ใน dir นี้ทุกครั้งที่ `/recap` — ก่อนอ่าน inbox

ใช้ arra-oracle:
```
arra_handoff()   ← บันทึก handoff context ตอนจบ session
arra_inbox()     ← อ่าน pending handoffs ตอนเริ่ม session
```
