#!/bin/bash
# statusline.sh — แสดง context % + บันทึก JSON ให้ force-rrr อ่าน

STATUSLINE_JSON="${TMPDIR:-${TMP:-${TEMP:-/tmp}}}/statusline-raw.json"
cat > "$STATUSLINE_JSON"

pct=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f: d = json.load(f)
cw = d.get('context_window', {})
print(int(cw.get('used_percentage', 0)))
" 2>/dev/null || echo 0)

used_k=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f: d = json.load(f)
cu = d.get('context_window', {}).get('current_usage', {})
total = cu.get('input_tokens',0) + cu.get('cache_creation_input_tokens',0) + cu.get('cache_read_input_tokens',0) + cu.get('output_tokens',0)
print(int(total/1000))
" 2>/dev/null || echo 0)

max_k=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f: d = json.load(f)
print(int(d.get('context_window',{}).get('context_window_size',0)/1000))
" 2>/dev/null || echo 0)

model=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f: d = json.load(f)
m = d.get('model', {})
print(m.get('display_name') or m.get('id') or '?')
" 2>/dev/null || echo "?")

dur_ms=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f: d = json.load(f)
print(int(d.get('cost',{}).get('total_duration_ms',0)))
" 2>/dev/null || echo 0)

cwd=$(python3 -c "
import json
with open('$STATUSLINE_JSON') as f: d = json.load(f)
print(d.get('workspace',{}).get('current_dir',''))
" 2>/dev/null || echo "")

s=$(( dur_ms / 1000 ))
h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
[ "$h" -gt 0 ] 2>/dev/null && dur="${h}h${m}m" || dur="${m}m"

branch=""
if [ -n "$cwd" ]; then
  branch=$(timeout 2 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi
git_info=""
if [ -n "$branch" ]; then
  dirty=""
  timeout 1 git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null || dirty="*"
  git_info=" on ${branch}${dirty}"
fi

echo "Ω ${pct}% ${used_k}k/${max_k}k • ${dur} • ${model}${git_info}"
