with days as (
    select calendar_date
    from unnest(generate_date_array(
        date '{{ var("calendar_first_day") }}', date '{{ var("calendar_last_day") }}'
    )) as calendar_date
),

flagged as (
    select
        days.calendar_date,
        -- BigQuery numbers weekdays from 1 (Sunday) to 7 (Saturday).
        extract(dayofweek from days.calendar_date) in (1, 7) as is_weekend,
        holidays.holiday_name
    from days
    left join {{ ref("colombian_holidays") }} as holidays
        on days.calendar_date = holidays.holiday_on
)

select
    calendar_date,
    is_weekend,
    holiday_name,
    not is_weekend and holiday_name is null as is_business_day,
    -- Business days up to and including this date. Legal terms run from the day after filing,
    -- so the business days after one date and up to another are the difference of their
    -- indexes, whatever kind of day the first one is.
    countif(not is_weekend and holiday_name is null) over (order by calendar_date)
        as business_day_index
from flagged
