"""Load the Claude Code hook scripts, which live outside any Python package."""

import importlib.util
from pathlib import Path
from types import ModuleType

import pytest

HOOKS_DIR = Path(__file__).resolve().parents[2] / ".claude" / "hooks"


def _load(name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(f"claude_hooks_{name}", HOOKS_DIR / f"{name}.py")
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="session")
def format_file() -> ModuleType:
    return _load("format_file")


@pytest.fixture(scope="session")
def run_checks() -> ModuleType:
    return _load("run_checks")
