"""PostToolUse hook: format and lint the Python file Claude just edited."""

import sys

import pytest

RUFF = [sys.executable, "-m", "ruff"]


class TestFilePathFrom:
    def test_reads_the_path_from_the_tool_input(self, format_file):
        payload = {"tool_name": "Edit", "tool_input": {"file_path": "a.py"}}
        assert format_file.file_path_from(payload) == "a.py"

    def test_falls_back_to_the_tool_response(self, format_file):
        payload = {"tool_name": "Write", "tool_input": {}, "tool_response": {"filePath": "b.py"}}
        assert format_file.file_path_from(payload) == "b.py"

    def test_returns_none_when_there_is_no_path(self, format_file):
        assert format_file.file_path_from({"tool_name": "Write"}) is None


class TestCommandsFor:
    def test_python_files_are_formatted_then_linted(self, format_file, tmp_path):
        target = tmp_path / "pipeline.py"
        resolved = str(target.resolve())
        assert format_file.commands_for(str(target), tmp_path) == [
            [*RUFF, "format", resolved],
            [*RUFF, "check", "--fix", resolved],
        ]

    def test_relative_paths_are_resolved_against_the_project(self, format_file, tmp_path):
        commands = format_file.commands_for("ingestion/car_source.py", tmp_path)
        assert commands[0][-1] == str((tmp_path / "ingestion" / "car_source.py").resolve())

    @pytest.mark.parametrize("name", ["README.md", "data.csv", "pyproject.toml", "ci.yml"])
    def test_other_files_are_left_alone(self, format_file, tmp_path, name):
        assert format_file.commands_for(str(tmp_path / name), tmp_path) == []

    def test_files_outside_the_project_are_never_touched(self, format_file, tmp_path):
        project = tmp_path / "project"
        project.mkdir()
        assert format_file.commands_for(str(tmp_path / "elsewhere.py"), project) == []

    @pytest.mark.parametrize("value", [None, ""])
    def test_a_missing_path_means_nothing_to_do(self, format_file, tmp_path, value):
        assert format_file.commands_for(value, tmp_path) == []


class TestRun:
    def test_fixable_problems_are_fixed_silently(self, format_file, tmp_path):
        target = tmp_path / "module.py"
        target.write_text("x=1\n", encoding="utf-8")
        payload = {"tool_name": "Write", "tool_input": {"file_path": str(target)}}

        assert format_file.run(payload, tmp_path) == (0, "")
        assert target.read_text(encoding="utf-8") == "x = 1\n"

    def test_unfixable_lint_errors_go_back_to_claude(self, format_file, tmp_path):
        target = tmp_path / "module.py"
        target.write_text("print(undefined_name)\n", encoding="utf-8")
        payload = {"tool_name": "Edit", "tool_input": {"file_path": str(target)}}

        code, message = format_file.run(payload, tmp_path)

        assert code == 2
        assert "F821" in message

    def test_non_python_edits_run_nothing(self, format_file, tmp_path):
        payload = {"tool_name": "Edit", "tool_input": {"file_path": str(tmp_path / "notes.md")}}
        assert format_file.run(payload, tmp_path) == (0, "")
