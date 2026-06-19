#!/usr/bin/env python3

import sys
import os
import subprocess
import signal
import time
import threading
from pathlib import Path

from faster_whisper import WhisperModel

AUDIO_FILE = "/tmp/dictate_recording.wav"
PID_FILE = "/tmp/dictate_daemon.pid"
REC_PID_FILE = "/tmp/dictate_rec.pid"
STATUS_FILE = "/tmp/dictate_status"

MODEL_SIZE = os.environ.get("DICTATE_MODEL", "base")
DEVICE = os.environ.get("DICTATE_DEVICE", "auto")
COMPUTE_TYPE = os.environ.get("DICTATE_COMPUTE_TYPE", "auto")


def _setup_cuda_paths():
    try:
        import sysconfig

        sp = sysconfig.get_path("purelib")
        cublas = Path(sp) / "nvidia/cublas/lib"
        cudnn = Path(sp) / "nvidia/cudnn/lib"
        libs = []
        if cublas.is_dir():
            libs.append(str(cublas))
        if cudnn.is_dir():
            libs.append(str(cudnn))
        if libs:
            existing = os.environ.get("LD_LIBRARY_PATH", "")
            os.environ["LD_LIBRARY_PATH"] = ":".join(libs) + (
                ":" + existing if existing else ""
            )
    except Exception:
        pass


_setup_cuda_paths()
print(
    f"[dictate] LD_LIBRARY_PATH={os.environ.get('LD_LIBRARY_PATH', '<not set>')}",
    flush=True,
)

model = None
model_ready = threading.Event()
recording = False
rec_process = None
transcribe_thread = None
stop_event = threading.Event()
pending_start = False


def on_ac_power():
    for supply in Path("/sys/class/power_supply").iterdir():
        online = supply / "online"
        if online.exists() and online.read_text().strip() == "1":
            return True
    return False


def cuda_available():
    try:
        import ctranslate2

        return ctranslate2.get_cuda_device_count() > 0
    except Exception:
        return False


def detect_device():
    if DEVICE != "auto":
        return DEVICE
    if on_ac_power() and cuda_available():
        return "cuda"
    return "cpu"


def detect_compute_type(device):
    if COMPUTE_TYPE != "auto":
        return COMPUTE_TYPE
    if device == "cuda":
        return "float16"
    return "int8"


def set_status(status):
    try:
        with open(STATUS_FILE, "w") as f:
            f.write(status)
    except Exception:
        pass


def wtype_text(text):
    try:
        subprocess.run(["wtype", text], check=False, capture_output=True)
    except Exception:
        pass


def transcription_loop():
    global recording
    last_transcribed_end = 0.0
    last_transcribe_time = 0
    MIN_INTERVAL = 1.0

    while recording and not stop_event.is_set():
        try:
            if not Path(AUDIO_FILE).exists():
                time.sleep(0.1)
                continue

            now = time.time()
            if now - last_transcribe_time < MIN_INTERVAL:
                time.sleep(0.1)
                continue

            last_transcribe_time = now

            try:
                segments, info = model.transcribe(
                    AUDIO_FILE,
                    beam_size=5,
                    vad_filter=True,
                    vad_parameters=dict(min_silence_duration_ms=500),
                    language=None,
                )
            except Exception as e:
                if "Invalid data found when processing input" in str(e):
                    time.sleep(0.2)
                    continue
                raise

            new_text_parts = []
            for segment in segments:
                if stop_event.is_set():
                    break
                if segment.start >= last_transcribed_end:
                    text = segment.text.strip()
                    if text:
                        new_text_parts.append(text)
                    last_transcribed_end = segment.end

            if new_text_parts:
                combined = " ".join(new_text_parts) + " "
                wtype_text(combined)
                print(f"[dictate] {combined.strip()}", flush=True)

        except Exception as e:
            print(f"[dictate] Error: {e}", flush=True)
            time.sleep(0.5)


def start_recording():
    global recording, rec_process, transcribe_thread

    if recording:
        return

    subprocess.run(
        ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", "0.4"],
        capture_output=True,
    )

    Path(AUDIO_FILE).unlink(missing_ok=True)
    Path(REC_PID_FILE).unlink(missing_ok=True)

    rec_process = subprocess.Popen(
        ["rec", "-c", "1", "-r", "16000", AUDIO_FILE],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    with open(REC_PID_FILE, "w") as f:
        f.write(str(rec_process.pid))

    recording = True
    stop_event.clear()
    set_status("listening")

    try:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "Dictate",
                "-i",
                "audio-input-microphone",
                "-t",
                "1500",
                "Listening...",
                "Press SUPER+CTRL+S to stop.",
            ]
        )
    except Exception:
        pass

    transcribe_thread = threading.Thread(target=transcription_loop, daemon=True)
    transcribe_thread.start()


def stop_recording():
    global recording, rec_process, transcribe_thread

    if not recording:
        return

    stop_event.set()
    recording = False

    if rec_process:
        rec_process.terminate()
        try:
            rec_process.wait(timeout=3)
        except Exception:
            rec_process.kill()
            rec_process.wait()
        rec_process = None

    if transcribe_thread:
        transcribe_thread.join(timeout=5)
        transcribe_thread = None

    Path(REC_PID_FILE).unlink(missing_ok=True)
    set_status("idle")

    try:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "Dictate",
                "-i",
                "text-x-generic",
                "-t",
                "2000",
                "Stopped",
                "Recording finished.",
            ]
        )
    except Exception:
        pass


def toggle_recording(signum=None, frame=None):
    global pending_start

    if not model_ready.is_set():
        pending_start = not pending_start
        status = "pending" if pending_start else "idle"
        set_status(status)
        return

    if recording:
        print("[dictate] Stopping...", flush=True)
        stop_recording()
    else:
        print("[dictate] Starting...", flush=True)
        start_recording()


def cleanup(signum=None, frame=None):
    stop_recording()
    Path(PID_FILE).unlink(missing_ok=True)
    Path(STATUS_FILE).unlink(missing_ok=True)
    print("[dictate] Daemon stopped", flush=True)
    sys.exit(0)


def main():
    device = detect_device()
    compute_type = detect_compute_type(device)

    print(
        f"[dictate] Daemon starting - Model: {MODEL_SIZE}, Device: {device}, Compute: {compute_type}",
        flush=True,
    )

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))
    set_status("idle")

    signal.signal(signal.SIGUSR1, toggle_recording)
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    global model
    model = WhisperModel(MODEL_SIZE, device=device, compute_type=compute_type)
    model_ready.set()

    if pending_start:
        start_recording()

    try:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "Dictate",
                "-i",
                "audio-input-microphone",
                "-t",
                "2000",
                "Dictate ready",
                "Press SUPER+CTRL+S to start.",
            ]
        )
    except Exception:
        pass

    print("[dictate] Ready - waiting for SIGUSR1 to toggle recording", flush=True)

    while True:
        signal.pause()


if __name__ == "__main__":
    main()
