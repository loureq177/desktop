#!/usr/bin/env python3
"""Check catalog.toml and what apply-apps makes of it.

Every special needs a free key, an app it can start and icons the shell has;
apply-apps must render each app of the catalog, under every browser engine, into
Lua that loads and JSON that parses. The files go to a temporary directory.

Usage: apps_check.py REPO
"""

import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

repo = Path(sys.argv[1])
qs = repo / "home/.config/quickshell"
problems = []

with open(repo / "home/.config/apps/catalog.toml", "rb") as f:
    catalog = tomllib.load(f)

line_icons = set(re.findall(r'^\s*"([a-z0-9-]+)":', (qs / "widgets/LineIcons.js").read_text(), re.M))
reserved = set(catalog["reserved"])

for b in catalog["browsers"]:
    if b.get("engine") not in ("firefox", "chromium"):
        problems.append(f"browser {b['id']}: engine is firefox or chromium")
    if not any(b.get(s) for s in ("pacman", "aur", "flatpak")):
        problems.append(f"browser {b['id']}: no package")

ids, keys = set(), {}
for c in catalog["category"]:
    where = f"category {c['id']}"
    if c["id"] in ids:
        problems.append(f"{where}: twice")
    ids.add(c["id"])
    key = c.get("key", "")
    if not re.fullmatch(r"[A-Z]", key) or key in reserved:
        problems.append(f"{where}: key {key!r} is not a free letter")
    elif key in keys:
        problems.append(f"{where}: key {key} is {keys[key]}'s too")
    keys[key] = c["id"]
    for icon in [c.get("icon", "")] + [a.get("icon", "") for a in c["apps"]]:
        if icon and icon not in line_icons:
            problems.append(f"{where}: {icon} is not in LineIcons.js")
    for a in c["apps"]:
        kinds = [k for k in ("url", "term", "exec") if k in a]
        if len(kinds) != 1:
            problems.append(f"{where}: {a['name']} needs one of url, term, exec")
        if "exec" in a and "class" not in a:
            problems.append(f"{where}: {a['name']} runs a program but names no window class")
        if a.get("app_icon", "").startswith("icons/") and not (qs / a["app_icon"]).is_file():
            problems.append(f"{where}: {a['app_icon']} is not in the repo")

# Every app as a special of its own, rendered once per engine.
os.environ["XDG_CONFIG_HOME"] = tmp = tempfile.mkdtemp()
try:
    loader = importlib.machinery.SourceFileLoader("apply_apps", str(repo / "home/.local/bin/apply-apps"))
    spec = importlib.util.spec_from_loader("apply_apps", loader)
    apps = importlib.util.module_from_spec(spec)
    loader.exec_module(apps)
    specials = []
    for c in catalog["category"]:
        for i, a in enumerate(c["apps"]):
            s = apps.special(c, a, c["key"])
            s["name"] = f"{c['id']}-{i}"
            specials.append(s)
    for b in catalog["browsers"]:
        apps.render(catalog, {"browser": b["id"], "special": specials})
        lua = Path(tmp) / "apps/apps.lua"
        if shutil.which("luac"):
            run = subprocess.run(["luac", "-p", str(lua)], capture_output=True, text=True)
            if run.returncode:
                problems.append(f"apps.lua for {b['id']}: {run.stderr.strip()}")
        shell = json.loads((Path(tmp) / "apps/apps.json").read_text())
        if len(shell["specials"]) != len(specials):
            problems.append(f"apps.json for {b['id']}: specials missing")
finally:
    shutil.rmtree(tmp)

print("\n".join(problems), file=sys.stderr)
sys.exit(1 if problems else 0)
