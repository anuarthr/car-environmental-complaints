"""The dbt project parses offline, so a broken model or YAML file fails before BigQuery runs it."""

from pathlib import Path

from dbt.cli.main import dbtRunner

PROJECT = Path(__file__).resolve().parents[2] / "transform"


def test_the_dbt_project_parses_without_warnings(tmp_path):
    # Warnings fail too: a deprecated syntax is cheaper to fix now than at the next major
    # version. Parsing needs no credentials, so this runs on any machine and in CI.
    result = dbtRunner().invoke(
        [
            "parse",
            "--project-dir",
            str(PROJECT),
            "--profiles-dir",
            str(PROJECT),
            "--target-path",
            str(tmp_path / "target"),
            "--log-path",
            str(tmp_path / "logs"),
            "--no-partial-parse",
            "--warn-error",
            "--quiet",
        ]
    )

    assert result.success, result.exception
