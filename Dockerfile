# ═══════════════════════════════════════════════════════════════
#  AI Audio Story Generator — Docker Image
#  Base: CUDA 12.8 + cuDNN + Ubuntu 22.04 (Python 3.10 built-in)
#  Verify tag at: https://hub.docker.com/r/nvidia/cuda/tags
# ═══════════════════════════════════════════════════════════════
FROM nvidia/cuda:12.8.0-cudnn9-devel-ubuntu22.04
# ── Environment ─────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV COQUI_TOS_AGREED=1
ENV NUMBA_CACHE_DIR=/app/numba_cache
ENV OLLAMA_MODELS=/app/models/ollama
ENV TMPDIR=/tmp

# ── System packages ─────────────────────────────────────────────
# ffmpeg and zstd are required by your start.sh — kept here
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3.10-dev \
    ffmpeg \
    zstd \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Ensure python3 / python / pip all point to 3.10
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 \
    && update-alternatives --install /usr/bin/python  python  /usr/bin/python3.10 1 \
    && pip install --upgrade pip setuptools --no-cache-dir

# ── Ollama ──────────────────────────────────────────────────────
RUN curl -fsSL https://ollama.com/install.sh | sh

# ── PyTorch — heaviest layer, cached unless version changes ─────
RUN pip install \
    torch==2.11.0+cu128 \
    torchaudio==2.11.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128 \
    --no-cache-dir

# ── Pinned ML dependencies (exactly as in your working start.sh) ─
RUN pip install \
    transformers==4.44.0 \
    numpy==1.24.4 \
    scipy==1.11.4 \
    librosa==0.10.0 \
    --force-reinstall --no-cache-dir

# ── TTS + FastAPI stack ──────────────────────────────────────────
RUN pip install \
    TTS \
    fastapi \
    uvicorn \
    python-multipart \
    requests \
    --ignore-installed blinker \
    --no-cache-dir

# ── torchcodec (as in your start.sh) ────────────────────────────
RUN pip install torchcodec --no-cache-dir

# ── Critical TTS patch — fixes weights_only error on load ───────
# Taken directly from your start.sh — must run AFTER TTS install
RUN sed -i \
    's/return torch.load(f, map_location=map_location, \*\*kwargs)/return torch.load(f, map_location=map_location, weights_only=False, **kwargs)/' \
    /usr/local/lib/python3.10/dist-packages/TTS/utils/io.py

# ── Pre-download XTTS v2 model (~2 GB baked into image) ─────────
# This avoids a slow download on every container start.
# The model is saved to ~/.local/share/tts/ inside the image.
RUN python3 -c "from TTS.api import TTS; TTS('tts_models/multilingual/multi-dataset/xtts_v2')"

# ── App directory ────────────────────────────────────────────────
WORKDIR /app
RUN mkdir -p /app/outputs /app/numba_cache /app/models/ollama

# Copy application files
COPY pipeline.py     .
COPY api.py          .
COPY entrypoint.sh   .
RUN chmod +x entrypoint.sh

# FastAPI port
EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
