-- Business days per year, counted by hand from Ley 51 de 1983:
-- 2024: 366 days, 104 weekend days and 16 holidays on weekdays (20 July was a Saturday and
--       8 December a Sunday), so 246.
-- 2025: 365 days, 104 weekend days and 16 holiday dates on weekdays (20 July was a Sunday, and
--       30 June held two holidays), so 245.
with expected as (
    select
        2024 as calendar_year,
        246 as business_days
    union all
    select
        2025 as calendar_year,
        245 as business_days
),

actual as (
    select
        extract(year from calendar_date) as calendar_year,
        countif(is_business_day) as business_days
    from {{ ref("int_calendar__business_days") }}
    group by calendar_year
)

select
    expected.calendar_year,
    expected.business_days as expected_business_days,
    actual.business_days as actual_business_days
from expected
left join actual on expected.calendar_year = actual.calendar_year
where actual.business_days is distinct from expected.business_days
