"""PostToolUse hook: format and lint each Python file right after Claude edits it.

Fixable problems are fixed in place. Anything ruff cannot fix is written to
stderr with exit code 2, which Claude Code hands back to Claude so the file is
corrected before work moves on.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

RUFF = [sys.executable, "-m", "ruff"]
PYTHON_SUFFIXES = frozenset({".py"})
BLOCK = 2


def file_path_from(payload: dict[str, Any]) -> str | None:
    """Return the path of the file the tool wrote, if the payload names one."""
    tool_input = payload.get("tool_input") or {}
    tool_response = payload.get("tool_response") or {}
    return tool_input.get("file_path") or tool_response.get("filePath") or None


def commands_for(file_path: str | None, project_dir: Path) -> list[list[str]]:
    """Return the commands to run for an edited file. Empty means nothing to do."""
    if not file_path:
        return []
    path = Path(file_path)
    if not path.is_absolute():
        path = project_dir / path
    path = path.resolve()
    if not path.is_relative_to(project_dir.resolve()):
        return []
    if path.suffix not in PYTHON_SUFFIXES:
        return []
    target = str(path)
    return [[*RUFF, "format", target], [*RUFF, "check", "--fix", target]]


def run(payload: dict[str, Any], project_dir: Path) -> tuple[int, str]:
    """Run the commands for the edited file. Return the exit code and the message for Claude."""
    failures = []
    for command in commands_for(file_path_from(payload), project_dir):
        result = subprocess.run(
            command,
            cwd=project_dir,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        if result.returncode != 0:
            failures.append((result.stdout + result.stderr).strip())
    if failures:
        return BLOCK, "ruff found problems it could not fix:\n" + "\n".join(failures)
    return 0, ""


def main() -> int:
    payload = json.load(sys.stdin)
    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or Path.cwd())
    code, message = run(payload, project_dir)
    if message:
        print(message, file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
