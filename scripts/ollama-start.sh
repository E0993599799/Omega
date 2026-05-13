#!/usr/bin/env bash
# Start Ollama + optional LiteLLM proxy for Claude Code compatibility
# Usage: ollama-start.sh [model]

set -euo pipefail

OLLAMA_EXE="${OLLAMA_EXE:-/mnt/d/ollamaapp/ollama.exe}"
OLLAMA_API="http://localhost:11434"
MODEL="${1:-qwen2.5-coder:7b}"
LITELLM_PORT="${LITELLM_PORT:-8082}"

log() { echo "[ollama] $*" >&2; }

# Check if Ollama running
if curl -sf "$OLLAMA_API/api/tags" >/dev/null 2>&1; then
  log "Ollama already running"
else
  log "Starting Ollama ($OLLAMA_EXE)..."
  if [[ ! -f "$OLLAMA_EXE" ]]; then
    log "ERROR: $OLLAMA_EXE not found"
    exit 1
  fi
  nohup "$OLLAMA_EXE" serve > /tmp/ollama.log 2>&1 &
  for i in $(seq 1 20); do
    sleep 1
    if curl -sf "$OLLAMA_API/api/tags" >/dev/null 2>&1; then
      log "Ollama started (${i}s)"
      break
    fi
    if [[ $i -eq 20 ]]; then
      log "ERROR: Ollama did not start after 20s — check /tmp/ollama.log"
      exit 1
    fi
  done
fi

# List available models
log "Available models:"
curl -sf "$OLLAMA_API/api/tags" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(f\"  - {m['name']}\")
" 2>/dev/null || log "(could not fetch model list)"

# Start LiteLLM proxy (Anthropic API ↔ Ollama bridge)
if curl -sf "http://localhost:$LITELLM_PORT/health" >/dev/null 2>&1; then
  log "LiteLLM proxy already running on port $LITELLM_PORT"
else
  if python3 -c "import litellm" >/dev/null 2>&1; then
    log "Starting LiteLLM proxy on port $LITELLM_PORT → ollama/$MODEL..."
    nohup python3 -m litellm \
      --model "ollama/$MODEL" \
      --port "$LITELLM_PORT" \
      --drop_params \
      > /tmp/litellm.log 2>&1 &
    echo $! > /tmp/omega-litellm.pid
    for i in $(seq 1 15); do
      sleep 1
      if curl -sf "http://localhost:$LITELLM_PORT/health" >/dev/null 2>&1; then
        log "LiteLLM proxy ready on :$LITELLM_PORT"
        break
      fi
    done
  else
    log "LiteLLM not installed — skipping proxy"
    log "Install: python3 -m pip install litellm --break-system-packages"
  fi
fi

# Print usage
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Ollama Local AI Active                              ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Ollama API   : $OLLAMA_API          ║"
echo "║  Active model : $MODEL"
if curl -sf "http://localhost:$LITELLM_PORT/health" >/dev/null 2>&1; then
echo "║  LiteLLM proxy: http://localhost:$LITELLM_PORT (Anthropic-compat)"
echo "║"
echo "║  To use with Claude Code:"
echo "║    export ANTHROPIC_API_KEY=ollama"
echo "║    export ANTHROPIC_BASE_URL=http://localhost:$LITELLM_PORT"
fi
echo "╚══════════════════════════════════════════════════════╝"
