#!/bin/bash
set -e

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   AI Audio Story Generator — Starting   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Fix DNS resolution inside RunPod containers
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

echo "[1/4] Starting Ollama..."
OLLAMA_MODELS=/app/models/ollama ollama serve > /tmp/ollama.log 2>&1 &
OLLAMA_PID=$!
echo "      Ollama PID: $OLLAMA_PID"

echo "[2/4] Waiting for Ollama to be ready..."
for i in $(seq 1 40); do
    if curl -sf http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        echo "      ✅ Ollama is ready! ($i attempts)"
        break
    fi
    if [ "$i" -eq 40 ]; then
        echo "      ❌ Ollama failed to start."
        cat /tmp/ollama.log
        exit 1
    fi
    echo "      Waiting... ($i/40)"
    sleep 3
done

echo "[3/4] Checking MythoMax model..."
echo "      (First run: ~8GB download — subsequent runs will be instant)"
OLLAMA_MODELS=/app/models/ollama ollama pull nollama/mythomax-l2-13b:Q4_K_M
echo "      ✅ Model ready!"

echo "[4/4] Starting FastAPI on port 8000..."
echo ""
echo "  🟢 API ready at: http://0.0.0.0:8000"
echo "  📋 Docs at:      http://0.0.0.0:8000/docs"
echo "  ❤️  Health:       http://0.0.0.0:8000/health"
echo ""

exec uvicorn api:app --host 0.0.0.0 --port 8000
