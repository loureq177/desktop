# Dictation's speech model, loaded while you speak and kept a minute (2 s to load, 0.3 to transcribe).
# On onnx-asr's own Python, which `dictation` takes from onnx-asr's shebang.
#
#   serve      load it and answer on $XDG_RUNTIME_DIR/dictation.sock until a minute unasked
#   ask WAV    print WAV's text; exit 1 when no model answers

import os
import signal
import socket
import sys

RUN_DIR = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
SOCKET = os.path.join(RUN_DIR, "dictation.sock")
DATA = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
MODEL = os.path.join(DATA, "parakeet", "parakeet-tdt-0.6b-v3-onnx")
IDLE = 60


# One thread a core: the SMT siblings made it slower (0.50 s against 0.37 for 11 s of speech).
def cores() -> int:
    base = "/sys/devices/system/cpu"
    seen = set()
    for cpu in os.listdir(base):
        try:
            with open(f"{base}/{cpu}/topology/core_cpus_list") as f:
                seen.add(f.read().strip())
        except OSError:
            pass
    return len(seen) or os.cpu_count() or 4


def bind() -> socket.socket | None:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.bind(SOCKET)
    except OSError:
        # One answers already (or is loading), or a dead one left its socket behind.
        probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            probe.connect(SOCKET)
            return None
        except OSError:
            os.unlink(SOCKET)
            sock.bind(SOCKET)
        finally:
            probe.close()
    sock.listen(4)
    return sock


def serve() -> None:
    sock = bind()
    if sock is None:
        return
    # Stopped (logout, pkill): the socket goes with it.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    mine = os.stat(SOCKET).st_ino
    try:
        import onnx_asr
        import onnxruntime

        options = onnxruntime.SessionOptions()
        options.intra_op_num_threads = cores()
        # 1.0 GB held instead of 1.3, as fast.
        options.enable_cpu_mem_arena = False
        model = onnx_asr.load_model("nemo-parakeet-tdt-0.6b-v3", MODEL, quantization="int8", sess_options=options)
        sock.settimeout(IDLE)
        while True:
            try:
                conn, _ = sock.accept()
            except TimeoutError:
                break
            with conn:
                conn.settimeout(10)
                path = conn.makefile("r", encoding="utf-8").readline().strip()
                # An empty line is another `serve` checking that one runs.
                if not path:
                    continue
                try:
                    reply = "ok\n" + model.recognize(path)
                except Exception as e:  # a bad file must not take the model down
                    reply = f"error\n{e}"
                try:
                    conn.sendall(reply.encode())
                except OSError:
                    pass
    finally:
        try:
            if os.stat(SOCKET).st_ino == mine:
                os.unlink(SOCKET)
        except OSError:
            pass
        sock.close()


def ask(path: str) -> int:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    # Loading takes 2 s; a long recording's transcription a few more.
    sock.settimeout(120)
    try:
        sock.connect(SOCKET)
        sock.sendall((os.path.abspath(path) + "\n").encode())
        sock.shutdown(socket.SHUT_WR)
        reply = b""
        while chunk := sock.recv(65536):
            reply += chunk
    except OSError:
        return 1
    status, _, text = reply.decode(errors="replace").partition("\n")
    if status != "ok":
        print(text, file=sys.stderr)
        return 1
    print(text)
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "serve":
        serve()
    elif len(sys.argv) == 3 and sys.argv[1] == "ask":
        sys.exit(ask(sys.argv[2]))
    else:
        print("usage: dictation-model.py serve | ask WAV", file=sys.stderr)
        sys.exit(2)
