#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  entrypoint.sh — Container startup script
#  Order: Ollama → wait for ready → pull model → FastAPI
# ═══════════════════════════════════════════════════════════════
set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   AI Audio Story Generator — Starting   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: Start Ollama as background process ───────────────────
echo "[1/4] Starting Ollama..."
OLLAMA_MODELS=/app/models/ollama ollama serve > /tmp/ollama.log 2>&1 &
OLLAMA_PID=$!
echo "      Ollama PID: $OLLAMA_PID"

# ── Step 2: Wait for Ollama to be healthy ───────────────────────
echo "[2/4] Waiting for Ollama to be ready..."
for i in $(seq 1 40); do
    if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        echo "      ✅ Ollama is ready! ($i attempts)"
        break
    fi
    if [ "$i" -eq 40 ]; then
        echo "      ❌ Ollama failed to start after 40 attempts."
        echo "      --- Ollama log ---"
        cat /tmp/ollama.log
        exit 1
    fi
    echo "      Waiting... ($i/40)"
    sleep 3
done

# ── Step 3: Pull MythoMax model (skips if already on mounted volume) ──
echo "[3/4] Checking MythoMax model..."
echo "      (First run: ~8GB download — subsequent runs will be instant)"
OLLAMA_MODELS=/app/models/ollama ollama pull nollama/mythomax-l2-13b:Q4_K_M
echo "      ✅ Model ready!"

# ── Step 4: Launch FastAPI ───────────────────────────────────────
echo "[4/4] Starting FastAPI on port 8000..."
echo ""
echo "  🟢 API ready at: http://0.0.0.0:8000"
echo "  📋 Docs at:      http://0.0.0.0:8000/docs"
echo "  ❤️  Health:       http://0.0.0.0:8000/health"
echo ""

# exec replaces this shell with uvicorn (proper signal handling)
exec uvicorn api:app --host 0.0.0.0 --port 8000
