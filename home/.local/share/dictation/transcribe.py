#!/usr/bin/env python3
import sys
import os

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    audio_path = sys.argv[1]
    if not os.path.exists(audio_path):
        sys.exit(1)

    try:
        from faster_whisper import WhisperModel
        model = WhisperModel("base", device="cpu", compute_type="int8")
        segments, info = model.transcribe(
            audio_path,
            beam_size=5,
            vad_filter=True,
            vad_parameters=dict(min_silence_duration_ms=400),
            initial_prompt="Dyktuję tekst po polsku lub po angielsku.",
        )
        text = "".join(s.text for s in segments).strip()
        if text:
            print(text)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
