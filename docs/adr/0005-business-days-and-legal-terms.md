# ADR 0005: Count business days and compare deadlines with the legal term

- Status: accepted
- Date: 2026-11-17

## Context

A complaint filed with CAR is a petition, and the law gives an authority a number of business
days to answer it: days that are neither weekends nor public holidays, counted from the day
after filing. Questions 1, 2 and 4 of this project need that count for every complaint.

CAR publishes, for each complaint, the deadline it recorded and a label saying whether the
answer came on time. Measured on the release of 2026-11-10, the label agrees in every row with
answering on or before the recorded deadline, but only 26.7% of recorded deadlines fall 15
business days after filing. The rest cluster at 30, and at 41 to 45, 60, 75 and 86 to 90
business days, and the mix changes by year and by regional office. They are not whole months nor
round numbers of calendar days, and the data says nothing about the rule behind them.

The legal term changed during the pandemic. Decreto Legislativo 491 de 2020, article 5, raised
the general term from 15 to 30 days from 2020-03-28, for petitions pending or filed during the
health emergency, and allowed doubling it if the filer was told before the deadline. Ley 2207
de 2022 repealed that article from 2022-05-18, with no transitional rule. Both texts were read
on alcaldiabogota.gov.co.

## Decision

- **Public holidays come from a versioned seed.** `python -m calendar_build` writes Colombia's
  holidays from 2008 to 2027 with the holidays library. Tests check 2024 and 2025 against dates
  derived from Ley 51 de 1983 and Easter, and fail when the versioned file differs from what the
  generator writes.
- **Business days are the difference of two indexes.** `int_calendar__business_days` has one row
  per date with a running count of business days, so a count between two dates is one
  subtraction. The calendar's years are dbt vars, which a test keeps equal to the generator's.
- **Every complaint keeps its row.** Dates are joined to the calendar with left joins on one row
  per date, so a complaint is never repeated, and a date outside the calendar leaves a null that
  a not_null test reports instead of dropping the complaint.
- **The legal term follows the filing date:** 30 business days for complaints filed from
  2020-03-28 to 2022-05-17, 15 otherwise. That is what CAR did: across the repeal, complaints
  filed under the decree kept 30 days. Petitions already pending on 2020-03-28, which the
  decree also covered, rarely got 30 days from CAR (7 of the 211 complaints filed in the three
  weeks before), so the model keeps 15 for them.
- **Compliance with the law is a range, not a number.** `answered_within_legal_term` is the
  strict reading; `answered_within_double_term` grants every extension the law allowed, since
  the data does not record which filers were told. The real figure lies between the two.
- **Impossible answers are not judged.** An answer dated before filing gets null, not on time.
- **CAR's own deadline and label stay.** The model adds the legal comparison next to them; it
  does not replace what CAR published.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Write the holidays by hand | About 360 dates with movable rules; easy to get one wrong, hard to review. |
| Compute holidays at run time in Python | Adds a dependency to the pipeline, and a library update would change counts without a diff. |
| Count business days with a range join | One row per complaint per day between two dates, millions of rows, for what a subtraction gives. |
| Take CAR's recorded deadline as the legal one | Only 31% of recorded deadlines match the legal term. |
| Give 30 days to petitions pending on 2020-03-28 | CAR rarely did: 7 of the 211 complaints filed in the three weeks before got 30 days. |

## Consequences

- A release with deadlines after 2027 fails the not_null tests on business days until the
  generator's years and the dbt vars are widened.
- The law sets 15 days "salvo norma especial". Complaints that a special procedure governs, such
  as an environmental sanctioning process, may have other terms, and the data does not say which
  ones they are. The legal comparison measures against the general term of a petition.
- The rule behind CAR's longer recorded deadlines remains an open question for CAR.
