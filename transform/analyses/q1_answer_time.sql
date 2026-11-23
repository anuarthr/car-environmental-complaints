-- Question 1: how long CAR takes to answer a complaint, and how that changed since 2009.
-- In business days, the unit of legal terms, by half-year of filing. Answers dated before the
-- filing date are recording errors and are left out of every measure.
with answered as (
    select
        format('%d-H%d', extract(year from filed_on), if(extract(month from filed_on) <= 6, 1, 2))
            as filed_half,
        business_days_to_answer,
        is_on_time_per_car,
        answered_within_legal_term
    from {{ ref("fct_complaints") }}
    where not is_answered_before_filing
),

-- percentile_cont is exact but analytic only in BigQuery, hence the window and distinct.
quantiles as (
    select distinct
        filed_half,
        percentile_cont(business_days_to_answer, 0.5) over (partition by filed_half)
            as median_business_days,
        percentile_cont(business_days_to_answer, 0.9) over (partition by filed_half)
            as p90_business_days
    from answered
),

halves as (
    select
        filed_half,
        count(*) as complaints,
        round(avg(business_days_to_answer), 1) as mean_business_days,
        round(100 * countif(is_on_time_per_car) / count(*), 1) as pct_on_time_per_car,
        round(100 * countif(answered_within_legal_term) / count(*), 1) as pct_within_legal_term
    from answered
    group by filed_half
)

select
    halves.filed_half,
    halves.complaints,
    quantiles.median_business_days,
    quantiles.p90_business_days,
    halves.mean_business_days,
    halves.pct_on_time_per_car,
    halves.pct_within_legal_term
from halves
inner join quantiles on halves.filed_half = quantiles.filed_half
order by halves.filed_half
