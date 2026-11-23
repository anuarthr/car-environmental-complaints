"""Colombian public holidays, generated into a dbt seed that business-day counts rely on.

The expected dates come from the law, not from the library: Ley 51 de 1983 (Ley Emiliani) moves
most holidays to the following Monday, and Holy Thursday and Good Friday follow Easter.
"""

from datetime import date
from pathlib import Path

import yaml

from calendar_build import holidays_seed

DBT_PROJECT = Path(__file__).resolve().parents[2] / "transform" / "dbt_project.yml"

# Easter 2024 was on March 31.
HOLIDAYS_2024 = {
    date(2024, 1, 1),  # Año Nuevo
    date(2024, 1, 8),  # Reyes Magos, Saturday 6 moved to Monday
    date(2024, 3, 25),  # San José, Tuesday 19 moved to Monday
    date(2024, 3, 28),  # Jueves Santo
    date(2024, 3, 29),  # Viernes Santo
    date(2024, 5, 1),  # Día del Trabajo
    date(2024, 5, 13),  # Ascensión, Easter + 39 days moved to Monday
    date(2024, 6, 3),  # Corpus Christi, Easter + 60 days moved to Monday
    date(2024, 6, 10),  # Sagrado Corazón, Easter + 68 days moved to Monday
    date(2024, 7, 1),  # San Pedro y San Pablo, Saturday 29 moved to Monday
    date(2024, 7, 20),  # Independencia, never moved
    date(2024, 8, 7),  # Batalla de Boyacá, never moved
    date(2024, 8, 19),  # Asunción, Thursday 15 moved to Monday
    date(2024, 10, 14),  # Día de la Raza, Saturday 12 moved to Monday
    date(2024, 11, 4),  # Todos los Santos, Friday 1 moved to Monday
    date(2024, 11, 11),  # Independencia de Cartagena, already a Monday
    date(2024, 12, 8),  # Inmaculada Concepción, never moved
    date(2024, 12, 25),  # Navidad
}

# Easter 2025 was on April 20.
HOLIDAYS_2025 = {
    date(2025, 1, 1),
    date(2025, 1, 6),
    date(2025, 3, 24),
    date(2025, 4, 17),
    date(2025, 4, 18),
    date(2025, 5, 1),
    date(2025, 6, 2),
    date(2025, 6, 23),
    # Sagrado Corazón (Easter + 68, Friday 27) and San Pedro y San Pablo (Sunday 29) both
    # moved to Monday 30: eighteen holidays on seventeen dates.
    date(2025, 6, 30),
    date(2025, 7, 20),
    date(2025, 8, 7),
    date(2025, 8, 18),
    date(2025, 10, 13),
    date(2025, 11, 3),
    date(2025, 11, 17),
    date(2025, 12, 8),
    date(2025, 12, 25),
}


def holiday_dates(first_year: int, last_year: int) -> set[date]:
    return {day for day, _ in holidays_seed.colombian_holidays(first_year, last_year)}


class TestColombianHolidays:
    def test_2024_matches_the_law(self):
        assert holiday_dates(2024, 2024) == HOLIDAYS_2024

    def test_2025_matches_the_law(self):
        assert holiday_dates(2025, 2025) == HOLIDAYS_2025

    def test_two_holidays_on_one_date_are_one_row_naming_both(self):
        names = dict(holidays_seed.colombian_holidays(2025, 2025))
        assert "Sagrado Corazón" in names[date(2025, 6, 30)]
        assert "San Pedro y San Pablo" in names[date(2025, 6, 30)]

    def test_a_moved_holiday_is_not_kept_on_its_original_date(self):
        assert date(2024, 1, 6) not in holiday_dates(2024, 2024)

    def test_only_the_requested_years_are_generated(self):
        assert {day.year for day in holiday_dates(2023, 2024)} == {2023, 2024}

    def test_rows_are_sorted_by_date(self):
        rows = holidays_seed.colombian_holidays(2008, 2027)
        assert rows == sorted(rows)


class TestSeedFile:
    def test_writes_a_header_and_one_iso_dated_row_per_holiday(self):
        rows = [(date(2024, 1, 1), "Año Nuevo"), (date(2024, 1, 8), "Día de los Reyes Magos")]
        assert holidays_seed.to_csv(rows) == (
            "holiday_on,holiday_name\n2024-01-01,Año Nuevo\n2024-01-08,Día de los Reyes Magos\n"
        )

    def test_main_writes_the_seed_as_utf8(self, tmp_path):
        output = tmp_path / "holidays.csv"

        assert holidays_seed.main(["--output", str(output)]) == 0

        text = output.read_text(encoding="utf-8")
        assert text.startswith("holiday_on,holiday_name\n2008-01-01,Año Nuevo\n")

    def test_the_dbt_calendar_spans_the_years_of_the_seed(self):
        # The calendar model generates one row per date between these vars; a date it covers
        # without holidays would count every holiday as a business day.
        project = yaml.safe_load(DBT_PROJECT.read_text(encoding="utf-8"))
        assert project["vars"]["calendar_first_day"] == f"{holidays_seed.FIRST_YEAR}-01-01"
        assert project["vars"]["calendar_last_day"] == f"{holidays_seed.LAST_YEAR}-12-31"

    def test_the_versioned_seed_is_what_the_generator_writes(self):
        # Fails when someone edits the seed by hand, or when an update of the holidays library
        # changes a date: regenerate it with `uv run python -m calendar_build` and review the
        # diff before merging.
        seed = Path(__file__).resolve().parents[2] / holidays_seed.SEED_PATH
        expected = holidays_seed.to_csv(
            holidays_seed.colombian_holidays(holidays_seed.FIRST_YEAR, holidays_seed.LAST_YEAR)
        )
        assert seed.read_text(encoding="utf-8") == expected
