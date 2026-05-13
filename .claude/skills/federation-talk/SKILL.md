---
name: federation-talk
description: ส่งข้อความหา Oracle ข้ามเครื่องผ่าน maw federation — ใช้ node:agent syntax
trigger: /federation-talk
---

# /federation-talk — Cross-Node Messaging

**Goal**: ส่งข้อความหา Oracle ข้ามเครื่องโดยตรง

## Usage

```
/federation-talk tham "message"              # ส่งหา tham (same node)
/federation-talk node-name:oracle "message"  # ส่ง cross-node
/federation-talk status                      # ดู federation topology
/federation-talk health                      # ตรวจ peer reachability
```

## Current Topology

```
tham-node (local — single node)
├── tham   (window 01)
└── omega  (window 02)  ← you are here

namedPeers: none (single-machine setup)
```

เมื่อ federate กับ node ใหม่:
```bash
# เพิ่ม peer ใน ~/.config/maw/maw.config.json:
# "namedPeers": [{"name": "other-node", "url": "http://IP:3457"}]
# แล้วใช้: maw hey other-node:oracle "message"
```

## Patterns ที่ใช้บ่อย

```bash
# Same-node (ปัจจุบัน)
maw talk-to tham "message"        # primary (audit trail)
maw hey tham "message"            # fallback (fast)

# Cross-node (ถ้า federate แล้ว)
maw hey node-name:tham "message"

# Health check
maw federation status
```

## Anti-Patterns ห้ามทำ

- `host: "0.0.0.0"` ใน config → ใช้ `bind: "0.0.0.0"` แทน
- `peers: [...]` array → ใช้ `namedPeers: [{"name": "...", "url": "..."}]`
- token ใน git — เก็บใน `~/.config/maw/maw.config.json` เท่านั้น
- node name ซ้ำกัน → แต่ละ node ต้องมีชื่อ unique

## Steps

1. ถ้า `/federation-talk status` → รัน `maw federation status` แสดงผล
2. ถ้า `/federation-talk health` → รัน `bash .claude/hooks/federation-health.sh` แล้วรายงาน
3. ถ้าส่งข้อความ → ใช้ `maw talk-to` หรือ `maw hey` ตาม usage
4. ถ้า peer offline → แจ้ง ธาม ด้วย `maw hey tham "alert: peer X offline"`
