"""
api.py — FastAPI wrapper for the AI Audio Story Generator
Replaces the CLI input() loop in pipeline.py with a proper HTTP API.
"""

import os
import uuid
import shutil
import tempfile
import requests
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
import torch
from TTS.api import TTS

# ── Config from environment (with sane defaults) ────────────────
OUTPUT_DIR   = os.getenv("OUTPUT_DIR",   "/app/outputs")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "nollama/mythomax-l2-13b:Q4_K_M")
OLLAMA_URL   = os.getenv("OLLAMA_URL",   "http://127.0.0.1:11434/api/generate")

os.makedirs(OUTPUT_DIR, exist_ok=True)

app = FastAPI(
    title="AI Audio Story Generator",
    description="Send a prompt + voice sample → get a narrated story audio file"
)

# ── Load XTTS once at startup (model already on disk from build) ─
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[startup] Device: {device}")
print("[startup] Loading XTTS v2 model...")
tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2", gpu=(device == "cuda"))
print("[startup] ✅ XTTS v2 ready.")


# ── Core functions (same logic as your pipeline.py) ─────────────

def generate_story(prompt: str) -> str:
    """Send prompt to Ollama → return generated story text."""
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": OLLAMA_MODEL,
            "prompt": (
                f"Write a detailed creative story based on this idea: {prompt}. "
                "Make it engaging, descriptive and at least 3 paragraphs long."
            ),
            "stream": False,
        },
        timeout=180,
    )
    response.raise_for_status()
    return response.json()["response"]


def generate_audio(story: str, voice_path: str) -> str:
    """Convert story text to audio using XTTS v2 with cloned voice."""
    output_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4()}.wav")
    tts.tts_to_file(
        text=story,
        speaker_wav=voice_path,
        language="en",
        file_path=output_path,
    )
    return output_path


# ── Endpoints ────────────────────────────────────────────────────

@app.get("/health")
def health():
    """Check that Ollama is running and XTTS is loaded."""
    try:
        r = requests.get("http://127.0.0.1:11434/api/tags", timeout=5)
        ollama_status = "ok" if r.status_code == 200 else "unavailable"
    except Exception:
        ollama_status = "unavailable"

    return {
        "status": "ok",
        "device": device,
        "ollama": ollama_status,
        "model": OLLAMA_MODEL,
    }


@app.post("/generate")
async def generate(
    prompt: str = Form(..., description="Your story idea or prompt"),
    voice: UploadFile = File(..., description="Voice sample to clone (.wav)"),
):
    """
    Generate a narrated audio story.

    - **prompt**: short story idea (e.g. 'a detective in a rainy city')
    - **voice**: .wav file of the voice to clone

    Returns: audio file path + the generated story text.
    """
    if not voice.filename.lower().endswith(".wav"):
        raise HTTPException(status_code=400, detail="Voice file must be a .wav file.")

    # Save uploaded voice to a temporary file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        shutil.copyfileobj(voice.file, tmp)
        voice_path = tmp.name

    try:
        print(f"[generate] Prompt: {prompt}")
        story = generate_story(prompt)
        print(f"[generate] Story generated ({len(story)} chars)")

        audio_path = generate_audio(story, voice_path)
        print(f"[generate] ✅ Audio saved: {audio_path}")

        return JSONResponse({
            "status":     "success",
            "audio_path": audio_path,
            "story":      story,
        })

    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="Ollama timed out generating story.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Always clean up the temp voice file
        if os.path.exists(voice_path):
            os.unlink(voice_path)
