#!/usr/bin/env python3
"""Check every `qs ipc call TARGET FUNCTION ARGS...` in the repo against the
IpcHandler blocks of the quickshell config: the target and function must exist
and the number of arguments must match.

Usage: ipc_check.py REPO FILE...   (FILE paths are relative to REPO)
"""

import re
import shlex
import sys
from pathlib import Path

SHELL_OPERATOR = set("();<>|&")
QUOTED_HOSTS = {".lua", ".qml", ".js"}  # the command sits inside a "..." string


def handlers(qml_dir):
    """{target: {function: argument count}} from all IpcHandler blocks."""
    found = {}
    for path in qml_dir.rglob("*.qml"):
        text = path.read_text(encoding="utf-8")
        for start in re.finditer(r"\bIpcHandler\s*\{", text):
            depth, i = 1, start.end()
            while depth and i < len(text):
                depth += {"{": 1, "}": -1}.get(text[i], 0)
                i += 1
            block = text[start.end() : i]
            target = re.search(r'\btarget:\s*"([^"]+)"', block)
            if not target:
                continue
            functions = found.setdefault(target.group(1), {})
            for name, params in re.findall(r"\bfunction\s+(\w+)\s*\(([^)]*)\)", block):
                functions[name] = len([p for p in params.split(",") if p.strip()])
    return found


def call_sites(repo, files):
    for rel in files:
        path = repo / rel
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(lines, 1):
            for match in re.finditer(r"\bqs\s+ipc\s+call\s+(.*)", line):
                rest = match.group(1)
                if path.suffix in QUOTED_HOSTS:
                    rest = rest.split('"', 1)[0]
                yield f"{rel}:{number}", rest


def words(rest):
    lexer = shlex.shlex(rest, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    out = []
    try:
        for token in lexer:
            if token and set(token) <= SHELL_OPERATOR:
                # "2>/dev/null", "200>&-": the fd number is not an argument
                if token.startswith(">") and out and out[-1].isdigit():
                    out.pop()
                break
            out.append(token)
    except ValueError:
        pass
    return out


def main():
    repo = Path(sys.argv[1])
    known = handlers(repo / "archlinux/.config/quickshell")
    if not known:
        sys.exit("no IpcHandler found: has the quickshell config moved?")

    problems, checked = [], 0
    for where, rest in call_sites(repo, sys.argv[2:]):
        tokens = words(rest)
        if len(tokens) < 2 or "$" in tokens[0]:
            continue
        target, function, args = tokens[0], tokens[1], tokens[2:]
        checked += 1
        if target not in known:
            problems.append(f"{where}: no IPC target '{target}' (have: {', '.join(sorted(known))})")
        elif "$" in function:
            continue
        elif function not in known[target]:
            problems.append(
                f"{where}: target '{target}' has no function '{function}' "
                f"(have: {', '.join(sorted(known[target]))})"
            )
        elif len(args) != known[target][function]:
            problems.append(
                f"{where}: {target}.{function} takes {known[target][function]} argument(s), "
                f"called with {len(args)}: {args}"
            )

    print(f"checked {checked} ipc calls against {sum(len(f) for f in known.values())} handler functions")
    if checked == 0:
        problems.append("found no `qs ipc call` at all: the scan is broken")
    if problems:
        sys.exit("\n".join(problems))


if __name__ == "__main__":
    main()
