---
name: ai-status
description: Show current AI provider status, switch providers, or activate Ollama local fallback
trigger: /ai-status
---

# /ai-status — AI Provider Status & Switch

**Goal**: ดู/เปลี่ยน AI provider ที่ใช้อยู่ — รองรับ Claude, ChatGPT, Gemini, และ Ollama local

## Usage

```
/ai-status              # แสดงสถานะ provider ทั้งหมด
/ai-status next         # rotate ไป provider ถัดไป
/ai-status use <name>   # เปลี่ยนไป provider ที่ระบุ
/ai-status ollama       # เปิด Ollama local + LiteLLM proxy
/ai-status env          # แสดง export commands สำหรับ shell
```

## Provider Priority Order

| Priority | Name | Type | Model |
|----------|------|------|-------|
| 01 | claude-primary | anthropic | claude-sonnet-4-6 |
| 02 | claude-secondary | anthropic | claude-sonnet-4-6 |
| 03 | openai-pro-1 | openai | gpt-4o |
| 04 | openai-pro-2 | openai | gpt-4o |
| 05 | gemini-pro | gemini | gemini-1.5-pro |
| 06 | gemini-free | gemini | gemini-1.5-flash |
| 99 | ollama-local | ollama | qwen2.5-coder:7b |

## Config Location

- **Providers config**: `~/.config/ai-providers/providers.json` (API keys here, never committed)
- **Active state**: `/tmp/omega-ai-provider-state.json`
- **Switch script**: `/mnt/d/Git/omega-oracle/scripts/ai-switch.sh`

## Ollama Local Models

Installed at `D:\ollamaapp`:
- `qwen2.5-coder:7b` — best for code tasks
- `qwen3.5:latest` — general purpose
- `qwen2.5:1.5b-instruct` — fast, lightweight
- `qwen2.5:0.5b-instruct` — ultra-fast, tiny
- `smollm2:360m` — minimal footprint

## Steps

1. ใช้ Bash: `bash /mnt/d/Git/omega-oracle/scripts/ai-switch.sh <subcommand>`
2. แสดงผลลัพธ์
3. ถ้า switch สำเร็จ → cc ธาม: `maw hey tham "cc: AI provider switched to <name>"`
4. ถ้าเปิด Ollama → แสดง env exports ให้ user copy

## Auto-Switch on Quota

Hook `quota-detect.sh` จะ detect 429/rate-limit errors อัตโนมัติ แล้ว rotate ไป provider ถัดไป
