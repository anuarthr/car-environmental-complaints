-- Question 3: do partial answers inflate the on-time rate? A Parcial answer leaves the
-- complaint open, yet CAR's label judges it by its date like a full one. Compares each answer
-- type, and how often it was given on the very day of the recorded deadline.
with complaints as (
    select
        answer_type,
        business_days_to_answer,
        is_on_time_per_car,
        answered_within_legal_term,
        answered_on = due_on as answered_on_due_day
    from {{ ref("fct_complaints") }}
    where not is_answered_before_filing
),

quantiles as (
    select distinct
        answer_type,
        percentile_cont(business_days_to_answer, 0.5) over (partition by answer_type)
            as median_business_days
    from complaints
)

select
    summary.answer_type,
    summary.complaints,
    summary.pct_of_complaints,
    quantiles.median_business_days,
    summary.pct_on_time_per_car,
    summary.pct_within_legal_term,
    summary.pct_answered_on_due_day
from (
    select
        answer_type,
        count(*) as complaints,
        round(100 * count(*) / sum(count(*)) over (), 1) as pct_of_complaints,
        round(100 * countif(is_on_time_per_car) / count(*), 1) as pct_on_time_per_car,
        round(100 * countif(answered_within_legal_term) / count(*), 1) as pct_within_legal_term,
        round(100 * countif(answered_on_due_day) / count(*), 1) as pct_answered_on_due_day
    from complaints
    group by answer_type
) as summary
inner join quantiles on summary.answer_type = quantiles.answer_type
order by summary.complaints desc
