#!/usr/bin/env python3
import os
import sys
import signal
import subprocess
from pathlib import Path
from threading import Event


def notify(msg, critical=True):
    level = "critical" if critical else "normal"
    subprocess.run(
        ["notify-send", "-t", "5000", "-u", level, "Dictate", msg], check=False
    )


def main():
    audio_file = Path(
        os.environ.get("DICTATE_AUDIO_FILE", "/tmp/dictate_recording.wav")
    )
    ready_event = Event()

    signal.signal(signal.SIGUSR1, lambda _s, _f: ready_event.set())

    try:
        from faster_whisper import WhisperModel

        model = WhisperModel(
            os.environ.get("DICTATE_MODEL", "base"),
            device=os.environ.get("DICTATE_DEVICE", "auto"),
            compute_type=os.environ.get("DICTATE_COMPUTE_TYPE", "default"),
        )
    except Exception as e:
        notify(f"Failed to load model: {e}")
        return sys.exit(1)

    max_wait = float(os.environ.get("DICTATE_MAX_WAIT", "60"))
    if not ready_event.wait(timeout=max_wait):
        notify("Recording timeout — no signal received")
        return sys.exit(1)

    if not audio_file.exists():
        return sys.exit(0)

    try:
        segments, _ = model.transcribe(
            str(audio_file),
            beam_size=5,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=500),
            initial_prompt="Dyktuję tekst po polsku. Here is English dictation.",
            condition_on_previous_text=False,
        )

        text = "".join(s.text for s in segments).strip()
        if text:
            subprocess.run(["wtype", f"{text} "], check=False)
    except Exception as e:
        notify(f"Transcription failed: {e}")
        sys.exit(1)
    finally:
        audio_file.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
