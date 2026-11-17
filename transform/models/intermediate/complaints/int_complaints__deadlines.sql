with complaints as (
    select
        complaint_id,
        filed_on,
        due_on,
        answered_on
    from {{ ref("stg_car__complaints") }}
),

calendar as (
    select
        calendar_date,
        business_day_index
    from {{ ref("int_calendar__business_days") }}
)

-- Left joins on a calendar with one row per date: no complaint is repeated, and a date outside
-- the calendar leaves its count null instead of dropping the complaint.
select
    complaints.complaint_id,
    complaints.filed_on,
    complaints.due_on,
    complaints.answered_on,
    date_diff(complaints.due_on, complaints.filed_on, day) as calendar_days_to_due,
    due_day.business_day_index - filed_day.business_day_index as business_days_to_due,
    date_diff(complaints.answered_on, complaints.filed_on, day) as calendar_days_to_answer,
    answered_day.business_day_index - filed_day.business_day_index as business_days_to_answer
from complaints
left join calendar as filed_day on complaints.filed_on = filed_day.calendar_date
left join calendar as due_day on complaints.due_on = due_day.calendar_date
left join calendar as answered_day on complaints.answered_on = answered_day.calendar_date
