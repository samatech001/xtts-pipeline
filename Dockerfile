FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV COQUI_TOS_AGREED=1
ENV NUMBA_CACHE_DIR=/app/numba_cache
ENV OLLAMA_MODELS=/app/models/ollama
ENV TMPDIR=/tmp

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

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 \
    && update-alternatives --install /usr/bin/python  python  /usr/bin/python3.10 1 \
    && pip install --upgrade pip setuptools --no-cache-dir

RUN curl -fsSL https://ollama.com/install.sh | sh

RUN pip install \
    torch==2.11.0+cu128 \
    torchaudio==2.11.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128 \
    --no-cache-dir

RUN pip install \
    transformers==4.44.0 \
    numpy==1.24.4 \
    scipy==1.11.4 \
    librosa==0.10.0 \
    --force-reinstall --no-cache-dir

RUN pip install \
    TTS==0.22.0 \
    fastapi \
    uvicorn \
    python-multipart \
    requests \
    --ignore-installed blinker \
    --no-cache-dir

RUN pip install torchcodec --no-cache-dir

RUN sed -i \
    's/return torch.load(f, map_location=map_location, \*\*kwargs)/return torch.load(f, map_location=map_location, weights_only=False, **kwargs)/' \
    /usr/local/lib/python3.10/dist-packages/TTS/utils/io.py

WORKDIR /app
RUN mkdir -p /app/outputs /app/numba_cache /app/models/ollama

COPY api.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
