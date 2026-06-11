#!/bin/bash

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   AI Audio Story Generator — Starting   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Fix DNS resolution inside RunPod containers
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# ── Step 1: Start Ollama ─────────────────────────────────────────
echo "[1/4] Starting Ollama..."
OLLAMA_MODELS=/app/models/ollama ollama serve > /tmp/ollama.log 2>&1 &
echo "      Ollama PID: $!"

# ── Step 2: Wait for Ollama ──────────────────────────────────────
echo "[2/4] Waiting for Ollama to be ready..."
for i in $(seq 1 40); do
    if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        echo "      ✅ Ollama is ready! ($i attempts)"
        break
    fi
    echo "      Waiting... ($i/40)"
    sleep 3
done

# ── Step 3: Pull MythoMax with retries ───────────────────────────
echo "[3/4] Pulling MythoMax model..."
echo "      (First run: ~8GB download — subsequent runs instant)"

for attempt in 1 2 3 4 5; do
    echo "      Attempt $attempt/5..."
    if OLLAMA_MODELS=/app/models/ollama ollama pull nollama/mythomax-l2-13b:Q4_K_M; then
        echo "      ✅ Model ready!"
        break
    fi
    if [ "$attempt" -eq 5 ]; then
        echo "      ⚠️ Model pull failed after 5 attempts — starting API anyway"
        echo "      Check DNS or network and restart the pod"
    fi
    echo "      Retrying in 10 seconds..."
    sleep 10
done

# ── Step 4: Start FastAPI ─────────────────────────────────────────
echo "[4/4] Starting FastAPI on port 8000..."
echo ""
echo "  🟢 API ready at: http://0.0.0.0:8000"
echo "  📋 Docs at:      http://0.0.0.0:8000/docs"
echo "  ❤️  Health:       http://0.0.0.0:8000/health"
echo ""

exec uvicorn api:app --host 0.0.0.0 --port 8000
