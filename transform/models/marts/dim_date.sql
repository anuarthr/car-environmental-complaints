select
    calendar_date,
    extract(year from calendar_date) as calendar_year,
    extract(quarter from calendar_date) as calendar_quarter,
    extract(month from calendar_date) as calendar_month,
    date_trunc(calendar_date, month) as month_start,
    -- %u is the ISO weekday, Monday 1 to Sunday 7, the way a Colombian calendar reads.
    cast(format_date('%u', calendar_date) as int64) as iso_weekday,
    is_weekend,
    holiday_name,
    is_business_day
from {{ ref("int_calendar__business_days") }}
