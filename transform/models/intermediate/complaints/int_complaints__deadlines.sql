with complaints as (
    select
        complaint_id,
        filed_on,
        due_on,
        answered_on,
        -- A complaint is a petition: 15 business days to answer (Ley 1437 de 2011, art. 14, as
        -- replaced by Ley 1755 de 2015). Decreto Legislativo 491 de 2020, art. 5, raised it to
        -- 30 from 2020-03-28, and Ley 2207 de 2022 repealed that from 2022-05-18 with no
        -- transition. CAR applied the term in force on the filing date, and so does this model.
        -- The decree also reached petitions pending on 2020-03-28, but CAR rarely gave them 30
        -- days, so this model keeps 15: in the release of 2026-11-10, of the 211 complaints
        -- filed from 2020-03-06 to 2020-03-27, 7 got 30 days, 49 got 15 and the rest others.
        if(filed_on between '2020-03-28' and '2022-05-17', 30, 15) as legal_term_business_days
    from {{ ref("stg_car__complaints") }}
),

calendar as (
    select
        calendar_date,
        is_business_day,
        business_day_index
    from {{ ref("int_calendar__business_days") }}
),

-- Each index value belongs to exactly one business day: the day the count reaches it.
business_days as (
    select
        calendar_date,
        business_day_index
    from calendar
    where is_business_day
),

-- Left joins on tables with one row per date or per index: no complaint is repeated, and a
-- date outside the calendar leaves a null instead of dropping the complaint.
measured as (
    select
        complaints.*,
        date_diff(complaints.due_on, complaints.filed_on, day) as calendar_days_to_due,
        due_day.business_day_index - filed_day.business_day_index as business_days_to_due,
        date_diff(complaints.answered_on, complaints.filed_on, day) as calendar_days_to_answer,
        answered_day.business_day_index - filed_day.business_day_index
            as business_days_to_answer,
        legal_due.calendar_date as legal_due_on,
        -- The law lets an authority double the term if it tells the filer before the deadline.
        -- The data does not say when CAR did, so this is the most generous legal deadline.
        double_due.calendar_date as double_due_on
    from complaints
    left join calendar as filed_day on complaints.filed_on = filed_day.calendar_date
    left join calendar as due_day on complaints.due_on = due_day.calendar_date
    left join calendar as answered_day on complaints.answered_on = answered_day.calendar_date
    left join business_days as legal_due
        on
            filed_day.business_day_index + complaints.legal_term_business_days
            = legal_due.business_day_index
    left join business_days as double_due
        on
            filed_day.business_day_index + 2 * complaints.legal_term_business_days
            = double_due.business_day_index
)

select
    complaint_id,
    filed_on,
    due_on,
    answered_on,
    calendar_days_to_due,
    business_days_to_due,
    calendar_days_to_answer,
    business_days_to_answer,
    legal_term_business_days,
    legal_due_on,
    business_days_to_due = legal_term_business_days as due_matches_legal_term,
    -- An answer dated before filing is a recording error, so whether it came on time is
    -- unknown. Dates are compared, not business days: an answer on the Saturday after the
    -- deadline is late.
    if(answered_on < filed_on, null, answered_on <= legal_due_on) as answered_within_legal_term,
    if(answered_on < filed_on, null, answered_on <= double_due_on) as answered_within_double_term
from measured
