"""Stop hook: run the test suite before Claude is allowed to finish a turn.

Exit code 2 blocks the stop and hands the failing tests back to Claude. When
Claude is already continuing because of this hook, the stop goes through, so a
suite that cannot be fixed never traps the session in a loop.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

PASSED = 0
NO_TESTS_COLLECTED = 5
BLOCK = 2


def should_skip(payload: dict[str, Any]) -> bool:
    """Skip when Claude is already continuing because this hook blocked a stop."""
    return payload.get("stop_hook_active") is True


def exit_code_for(pytest_returncode: int) -> int:
    """Map a pytest exit code to the hook exit code."""
    return 0 if pytest_returncode in (PASSED, NO_TESTS_COLLECTED) else BLOCK


def feedback(pytest_output: str, max_lines: int = 40) -> str:
    """Build the message for Claude from the end of the pytest output."""
    tail = pytest_output.strip().splitlines()[-max_lines:]
    return "Tests are failing. Fix them before finishing:\n" + "\n".join(tail)


def main() -> int:
    raw = sys.stdin.read()
    payload = json.loads(raw) if raw.strip() else {}
    if should_skip(payload):
        return 0
    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR") or payload.get("cwd") or Path.cwd())
    result = subprocess.run(
        [sys.executable, "-m", "pytest", "-q", "--no-header"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    code = exit_code_for(result.returncode)
    if code == BLOCK:
        print(feedback(result.stdout + result.stderr), file=sys.stderr)
    return code


if __name__ == "__main__":
    sys.exit(main())
