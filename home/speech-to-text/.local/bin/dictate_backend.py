#!/usr/bin/env python3
import os
import sys
import signal
import subprocess
from pathlib import Path
from threading import Event

import torch
from faster_whisper import WhisperModel


def main():
    ready_event = Event()
    signal.signal(signal.SIGUSR1, lambda _signum, _frame: ready_event.set())

    audio_file = os.environ.get("DICTATE_AUDIO_FILE", "/tmp/dictate_recording.wav")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    compute_type = "float16" if device == "cuda" else "int8"
    model = WhisperModel(
        os.environ.get("DICTATE_MODEL", "base"),
        device=device,
        compute_type=compute_type,
    )

    ready_event.wait()

    if not Path(audio_file).exists():
        sys.exit(0)

    segments, _ = model.transcribe(
        audio_file,
        beam_size=5,
        vad_filter=True,
        initial_prompt="Dyktuję tekst po polsku. Here is English dictation.",
        condition_on_previous_text=False,
    )

    text = "".join(s.text for s in segments).strip()
    if text:
        subprocess.run(["wtype", f"{text} "], check=False)


if __name__ == "__main__":
    main()
