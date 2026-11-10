"""A run loads a dataset only when its publisher has released a newer version of it."""

from datetime import UTC, datetime, timedelta

import pytest

from ingestion.release import ReleaseWentBackwards, is_new_release, released_at

# The release CAR published on 2026-01-21, as datos.gov.co reports it in rowsUpdatedAt.
CURRENT_RELEASE = datetime(2026, 1, 21, 16, 56, 44, tzinfo=UTC)
CURRENT_RELEASE_EPOCH = 1769014604


class TestReleasedAt:
    def test_reads_rows_updated_at_as_utc(self):
        assert released_at({"rowsUpdatedAt": CURRENT_RELEASE_EPOCH}) == CURRENT_RELEASE

    def test_ignores_edits_that_only_touch_the_description(self):
        # viewLastModified moved in September 2026 although no row changed.
        metadata = {"rowsUpdatedAt": CURRENT_RELEASE_EPOCH, "viewLastModified": 1790023793}
        assert released_at(metadata) == CURRENT_RELEASE

    def test_fails_clearly_when_the_api_stops_reporting_it(self):
        with pytest.raises(ValueError, match="rowsUpdatedAt"):
            released_at({"viewLastModified": 1790023793})


class TestIsNewRelease:
    def test_the_first_run_loads(self):
        assert is_new_release(CURRENT_RELEASE, last_loaded=None)

    def test_a_release_already_loaded_is_skipped(self):
        assert not is_new_release(CURRENT_RELEASE, last_loaded=CURRENT_RELEASE)

    def test_a_later_release_loads(self):
        next_year = CURRENT_RELEASE + timedelta(days=365)
        assert is_new_release(next_year, last_loaded=CURRENT_RELEASE)

    def test_a_release_older_than_the_last_load_stops_the_run(self):
        one_second_earlier = CURRENT_RELEASE - timedelta(seconds=1)
        with pytest.raises(ReleaseWentBackwards):
            is_new_release(one_second_earlier, last_loaded=CURRENT_RELEASE)
