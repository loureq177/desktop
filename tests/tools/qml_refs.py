#!/usr/bin/env python3
"""Check member access on the quickshell singletons and JS modules.

QML resolves `Theme.fooBar` or `WeatherModel.parseX()` only when the line runs,
and a typo there is just `undefined` at runtime. This looks for uses of a name
that the singleton / module does not define.

Usage: qml_refs.py QUICKSHELL_DIR
"""

import re
import sys
from pathlib import Path

DEFINITION = re.compile(
    r"^\s*(?:default\s+|required\s+|readonly\s+)*property\s+(?:[\w.]+(?:<[^>]*>)?)\s+(\w+)"
    r"|^\s*function\s+(\w+)"
    r"|^\s*signal\s+(\w+)",
    re.M,
)
# Members every QObject / Quickshell singleton has without declaring them.
BUILTIN = {"objectName", "destroy", "toString", "connect", "disconnect"}


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"(?m)(^|\s)//.*$", r"\1", text)


def defined_in_qml(text):
    names = set()
    for groups in DEFINITION.findall(text):
        name = next(g for g in groups if g)
        names.add(name)
        # every property has a change signal and handler
        names.add(f"{name}Changed")
        names.add(f"on{name[0].upper()}{name[1:]}Changed")
    return names


def main():
    root = Path(sys.argv[1]).resolve()
    sources = {p: strip_comments(p.read_text(encoding="utf-8")) for p in root.rglob("*.qml")}
    scripts = {p: strip_comments(p.read_text(encoding="utf-8")) for p in root.rglob("*.js")}

    owners = {}  # name used in code -> (defining file, defined members)
    for path, text in sources.items():
        if re.search(r"^\s*pragma\s+Singleton\b", text, re.M):
            owners[path.stem] = (path, defined_in_qml(text))
    for path, text in sources.items():
        for file_name, alias in re.findall(r'^\s*import\s+"([^"]+\.js)"\s+as\s+(\w+)', text, re.M):
            module = (path.parent / file_name).resolve()
            if module.exists():
                functions = set(re.findall(r"^function\s+(\w+)", strip_comments(module.read_text(encoding="utf-8")), re.M))
                owners[alias] = (module, functions)

    problems, checked = [], 0
    for path, text in {**sources, **scripts}.items():
        for line_number, line in enumerate(text.splitlines(), 1):
            if re.match(r"\s*import\b", line):
                continue
            for owner, member in re.findall(r"(?<![\w.\"'])([A-Z]\w*)\.([A-Za-z_]\w*)", line):
                if owner not in owners or owners[owner][0] == path:
                    continue
                checked += 1
                if member not in owners[owner][1] and member not in BUILTIN:
                    problems.append(
                        f"{path.relative_to(root)}:{line_number}: {owner}.{member} is not defined in "
                        f"{owners[owner][0].relative_to(root)}"
                    )

    print(f"checked {checked} member uses of {', '.join(sorted(owners))}")
    if checked == 0:
        problems.append("found nothing to check: the scan is broken")
    if problems:
        sys.exit("\n".join(sorted(set(problems))))


if __name__ == "__main__":
    main()
