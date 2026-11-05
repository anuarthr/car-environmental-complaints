"""Stop hook: Claude cannot finish a turn while the test suite is failing."""

import pytest


class TestShouldSkip:
    def test_skips_when_claude_is_already_continuing_because_of_this_hook(self, run_checks):
        assert run_checks.should_skip({"stop_hook_active": True}) is True

    @pytest.mark.parametrize("payload", [{}, {"stop_hook_active": False}])
    def test_runs_otherwise(self, run_checks, payload):
        assert run_checks.should_skip(payload) is False


class TestExitCodeFor:
    @pytest.mark.parametrize("pytest_code", [0, 5])
    def test_a_passing_or_empty_suite_lets_claude_stop(self, run_checks, pytest_code):
        assert run_checks.exit_code_for(pytest_code) == 0

    @pytest.mark.parametrize("pytest_code", [1, 2, 3, 4])
    def test_anything_else_blocks_the_stop(self, run_checks, pytest_code):
        assert run_checks.exit_code_for(pytest_code) == 2


class TestFeedback:
    def test_keeps_only_the_tail_of_the_pytest_output(self, run_checks):
        output = "\n".join(f"line {i}" for i in range(100))
        message = run_checks.feedback(output, max_lines=5)

        assert message.splitlines()[-5:] == [f"line {i}" for i in range(95, 100)]
        assert "line 94" not in message

    def test_tells_claude_what_to_do(self, run_checks):
        assert run_checks.feedback("1 failed").startswith("Tests are failing")
