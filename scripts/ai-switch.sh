#!/usr/bin/env bash
# AI Provider switcher — rotates through providers when quota is hit
# Usage: ai-switch.sh [status|next|use <name>|ollama]

set -euo pipefail

PROVIDERS_CONFIG="${AI_PROVIDERS_CONFIG:-$HOME/.config/ai-providers/providers.json}"
STATE_FILE="/tmp/omega-ai-provider-state.json"
OLLAMA_EXE="/mnt/d/ollamaapp/ollama.exe"
# Dynamically detect Windows host IP for WSL2 → Windows networking
WIN_IP=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | awk '{print $2}' | head -1)
OLLAMA_API="http://${WIN_IP:-127.0.0.1}:11434"
LITELLM_PORT="${LITELLM_PORT:-8082}"
LITELLM_PID_FILE="/tmp/omega-litellm.pid"

# ─── helpers ────────────────────────────────────────────────────────────────

log() { echo "[ai-switch] $*" >&2; }

# python3-based JSON reader (no jq needed)
py_read() {
  python3 - "$1" "$2" <<'PYEOF'
import sys, json
data = json.load(open(sys.argv[1]))
keys = sys.argv[2].split(".")
for k in keys:
    if isinstance(data, list):
        data = data[int(k)]
    else:
        data = data[k]
print(data)
PYEOF
}

get_active() {
  if [[ -f "$STATE_FILE" ]]; then
    python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('active','claude-primary'))"
  else
    python3 -c "import json; d=json.load(open('$PROVIDERS_CONFIG')); print(d.get('active','claude-primary'))"
  fi
}

get_providers() {
  python3 -c "
import json
d = json.load(open('$PROVIDERS_CONFIG'))
for p in d['providers']:
    if p.get('enabled', True):
        print(p['name'])
"
}

get_provider_field() {
  local name="$1" field="$2"
  python3 -c "
import json
d = json.load(open('$PROVIDERS_CONFIG'))
for p in d['providers']:
    if p['name'] == '$name':
        print(p.get('$field', ''))
        break
"
}

set_state() {
  local provider="$1"
  local key
  key=$(get_provider_field "$provider" "api_key")
  local key_env
  key_env=$(get_provider_field "$provider" "api_key_env")
  local base_url
  base_url=$(get_provider_field "$provider" "base_url")
  local model
  model=$(get_provider_field "$provider" "model")
  local ptype
  ptype=$(get_provider_field "$provider" "type")

  python3 - "$STATE_FILE" "$provider" "$key" "$key_env" "$base_url" "$model" "$ptype" <<'PYEOF'
import sys, json
state = {
    "active": sys.argv[2],
    "api_key": sys.argv[3],
    "api_key_env": sys.argv[4],
    "base_url": sys.argv[5],
    "model": sys.argv[6],
    "type": sys.argv[7]
}
json.dump(state, open(sys.argv[1], "w"), indent=2)
PYEOF
  log "switched to: $provider (model: $model)"
}

# ─── Ollama management ───────────────────────────────────────────────────────

ollama_running() {
  curl -sf "$OLLAMA_API/api/tags" >/dev/null 2>&1
}

ollama_start() {
  if ollama_running; then
    log "Ollama already running at $OLLAMA_API"
    return 0
  fi
  log "Starting Ollama from $OLLAMA_EXE..."
  if [[ ! -f "$OLLAMA_EXE" ]]; then
    log "ERROR: Ollama exe not found at $OLLAMA_EXE"
    return 1
  fi
  # Start Ollama as Windows process via PowerShell (nohup doesn't work for Windows exes in WSL2)
  local WIN_EXE
  WIN_EXE=$(wslpath -w "$OLLAMA_EXE" 2>/dev/null || echo 'D:\ollamaapp\ollama.exe')
  powershell.exe -Command "\$env:OLLAMA_HOST='0.0.0.0:11434'; Start-Process '$WIN_EXE' -ArgumentList 'serve' -WindowStyle Hidden" 2>/dev/null &
  log "Waiting for Ollama to start at $OLLAMA_API..."
  for i in $(seq 1 20); do
    sleep 1
    if ollama_running; then
      log "Ollama ready"
      return 0
    fi
  done
  log "ERROR: Ollama did not start within 20s — OLLAMA_HOST must be 0.0.0.0:11434"
  return 1
}

litellm_running() {
  curl -sf "http://localhost:$LITELLM_PORT/health" >/dev/null 2>&1
}

litellm_start() {
  local ollama_model="$1"
  if litellm_running; then
    log "LiteLLM proxy already running on port $LITELLM_PORT"
    return 0
  fi
  if ! command -v litellm >/dev/null 2>&1; then
    log "LiteLLM not found — trying python3 -m litellm"
    if ! python3 -c "import litellm" >/dev/null 2>&1; then
      log "ERROR: litellm not installed. Run: python3 -m pip install litellm"
      return 1
    fi
    nohup python3 -m litellm.proxy.proxy_server \
      --model "ollama/$ollama_model" \
      --port "$LITELLM_PORT" \
      --drop_params \
      > /tmp/litellm.log 2>&1 &
  else
    nohup litellm --model "ollama/$ollama_model" --port "$LITELLM_PORT" --drop_params \
      > /tmp/litellm.log 2>&1 &
  fi
  echo $! > "$LITELLM_PID_FILE"
  log "LiteLLM proxy starting (PID $!) on port $LITELLM_PORT..."
  for i in $(seq 1 15); do
    sleep 1
    if litellm_running; then
      log "LiteLLM proxy ready — Anthropic API proxied to Ollama"
      return 0
    fi
  done
  log "ERROR: LiteLLM proxy did not start within 15s"
  return 1
}

litellm_stop() {
  if [[ -f "$LITELLM_PID_FILE" ]]; then
    local pid
    pid=$(cat "$LITELLM_PID_FILE")
    kill "$pid" 2>/dev/null && log "Stopped LiteLLM proxy (PID $pid)"
    rm -f "$LITELLM_PID_FILE"
  fi
}

activate_ollama() {
  local ollama_model
  ollama_model=$(get_provider_field "ollama-local" "model")
  log "Activating Ollama fallback: $ollama_model"
  ollama_start || return 1
  litellm_start "$ollama_model" || return 1

  # Write state with litellm proxy as the Anthropic-compatible endpoint
  python3 - "$STATE_FILE" "$ollama_model" <<'PYEOF'
import sys, json
state = {
    "active": "ollama-local",
    "api_key": "ollama",
    "api_key_env": "ANTHROPIC_API_KEY",
    "base_url": f"http://localhost:{__import__('os').environ.get('LITELLM_PORT', '8082')}",
    "model": sys.argv[2],
    "type": "ollama"
}
json.dump(state, open(sys.argv[1], "w"), indent=2)
PYEOF

  log "Ollama provider active. To use with Claude Code:"
  log "  export ANTHROPIC_API_KEY=ollama"
  log "  export ANTHROPIC_BASE_URL=http://localhost:$LITELLM_PORT"
}

# ─── export env for current session ─────────────────────────────────────────

apply_to_env() {
  if [[ ! -f "$STATE_FILE" ]]; then
    log "No state file — using defaults"
    return 0
  fi
  local ptype active key base_url
  active=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['active'])")
  ptype=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['type'])")
  key=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['api_key'])")
  base_url=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d['base_url'])")

  echo "export ANTHROPIC_API_KEY='$key'"
  echo "export ANTHROPIC_BASE_URL='$base_url'"
  echo "export AI_ACTIVE_PROVIDER='$active'"
  echo "export AI_PROVIDER_TYPE='$ptype'"
}

# ─── next provider rotation ──────────────────────────────────────────────────

rotate_next() {
  local current
  current=$(get_active)
  local all_providers
  mapfile -t all_providers < <(get_providers)
  local total=${#all_providers[@]}

  local found=0 next_name=""
  for i in $(seq 0 $((total - 1))); do
    if [[ "${all_providers[$i]}" == "$current" ]]; then
      found=1
      local next_i=$(( (i + 1) % total ))
      next_name="${all_providers[$next_i]}"
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    next_name="${all_providers[0]}"
  fi

  log "Rotating: $current → $next_name"
  if [[ "$next_name" == "ollama-local" ]]; then
    activate_ollama
  else
    set_state "$next_name"
  fi
  echo "$next_name"
}

# ─── status ─────────────────────────────────────────────────────────────────

show_status() {
  local active
  active=$(get_active)
  echo "=== AI Provider Status ==="
  echo "Active: $active"
  echo ""
  echo "Available providers:"
  python3 - "$PROVIDERS_CONFIG" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
active_state_file = "/tmp/omega-ai-provider-state.json"
import os
try:
    state = json.load(open(active_state_file))
    active = state["active"]
except:
    active = d.get("active", "claude-primary")

for p in d["providers"]:
    enabled = p.get("enabled", True)
    marker = "★" if p["name"] == active else ("·" if enabled else "○")
    model = p.get("model", "?")
    ptype = p.get("type", "?")
    has_key = bool(p.get("api_key") or os.environ.get(p.get("api_key_env", ""), ""))
    key_status = "keyed" if has_key else "no-key"
    print(f"  {marker} [{p['priority']:02d}] {p['name']:<18} {ptype:<10} {model:<25} {key_status}")
PYEOF
  echo ""
  echo "Ollama: $(ollama_running && echo 'running' || echo 'stopped')"
  echo "LiteLLM: $(litellm_running && echo "running on :$LITELLM_PORT" || echo 'stopped')"
}

# ─── main ───────────────────────────────────────────────────────────────────

CMD="${1:-status}"
shift || true

case "$CMD" in
  status)
    show_status
    ;;
  next|rotate)
    rotate_next
    ;;
  use)
    NAME="${1:-}"
    if [[ -z "$NAME" ]]; then
      echo "Usage: ai-switch.sh use <provider-name>"
      exit 1
    fi
    if [[ "$NAME" == "ollama"* ]]; then
      activate_ollama
    else
      set_state "$NAME"
    fi
    ;;
  env)
    apply_to_env
    ;;
  ollama-start)
    ollama_start
    ;;
  ollama-stop)
    pkill -f "ollama.exe serve" 2>/dev/null && log "Ollama stopped" || log "Ollama not running"
    ;;
  litellm-start)
    MODEL="${1:-$(get_provider_field 'ollama-local' 'model')}"
    litellm_start "$MODEL"
    ;;
  litellm-stop)
    litellm_stop
    ;;
  *)
    echo "Usage: ai-switch.sh <status|next|use <name>|env|ollama-start|ollama-stop|litellm-start|litellm-stop>"
    exit 1
    ;;
esac
