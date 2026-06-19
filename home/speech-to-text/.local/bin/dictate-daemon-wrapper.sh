#!/bin/bash

DIR="$(dirname "$(realpath "$0")")"
VENV_PYTHON="$HOME/.files/.venv/bin/python"

SITE_PACKAGES=$("$VENV_PYTHON" -c "import sysconfig; print(sysconfig.get_path('purelib'))")
export LD_LIBRARY_PATH="${SITE_PACKAGES}/nvidia/cublas/lib:${SITE_PACKAGES}/nvidia/cudnn/lib:${LD_LIBRARY_PATH:-}"

exec "$VENV_PYTHON" "$DIR/dictate_daemon.py"
