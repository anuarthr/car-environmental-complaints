"""Write Colombia's public holidays to a dbt seed.

uv run python -m calendar_build    # regenerate transform/seeds/colombian_holidays.csv

The seed is versioned instead of computed at run time, so a change in the holidays library shows
up as a diff to review, not as counts that move without notice.
"""

from __future__ import annotations

import argparse
import csv
import io
from collections.abc import Iterable, Sequence
from datetime import date
from pathlib import Path

import holidays

# The first complaint was filed on 2009-01-02, and a complaint filed late in 2026 falls due in
# 2027. A deadline outside these years fails a dbt test, which is the cue to widen them.
FIRST_YEAR = 2008
LAST_YEAR = 2027
SEED_PATH = Path("transform") / "seeds" / "colombian_holidays.csv"


def colombian_holidays(first_year: int, last_year: int) -> list[tuple[date, str]]:
    """Every public holiday from first_year to last_year, sorted by date.

    Holidays that Ley 51 de 1983 moves to a Monday appear only on that Monday. Two holidays on
    the same date are one row whose name lists both.
    """
    calendar = holidays.Colombia(years=range(first_year, last_year + 1), language="es")
    return sorted(calendar.items())


def to_csv(rows: Iterable[tuple[date, str]]) -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(["holiday_on", "holiday_name"])
    writer.writerows((day.isoformat(), name) for day, name in rows)
    return buffer.getvalue()


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=SEED_PATH, help="CSV file to write")
    args = parser.parse_args(argv)
    rows = colombian_holidays(FIRST_YEAR, LAST_YEAR)
    args.output.write_text(to_csv(rows), encoding="utf-8", newline="\n")
    print(f"Wrote {len(rows)} holidays from {FIRST_YEAR} to {LAST_YEAR} to {args.output}")
    return 0
