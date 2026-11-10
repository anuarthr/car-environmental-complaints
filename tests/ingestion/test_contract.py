"""A run stops before downloading anything when the source publishes different columns."""

import pytest

from ingestion.contract import ColumnsChanged, check_columns

EXPECTED = ("item", "municipio", "tema")


def metadata_with(*field_names: str) -> dict:
    """Build the part of the Socrata view metadata that lists the published columns."""
    return {"columns": [{"fieldName": name} for name in field_names]}


def test_the_same_columns_in_another_order_pass():
    check_columns(metadata_with("tema", "item", "municipio"), expected=EXPECTED)


def test_an_added_column_stops_the_run():
    with pytest.raises(ColumnsChanged, match="added: vereda_nueva"):
        check_columns(metadata_with(*EXPECTED, "vereda_nueva"), expected=EXPECTED)


def test_a_removed_column_stops_the_run():
    with pytest.raises(ColumnsChanged, match="removed: tema"):
        check_columns(metadata_with("item", "municipio"), expected=EXPECTED)


def test_a_renamed_column_is_reported_as_added_and_removed():
    with pytest.raises(ColumnsChanged, match="added: tema_ambiental; removed: tema"):
        check_columns(metadata_with("item", "municipio", "tema_ambiental"), expected=EXPECTED)
