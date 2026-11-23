-- Each aggregate mart must add up to the fact table: a group dropped by a filter or a join
-- would vanish from every chart without an error.
with totals as (
    select
        (select count(*) from {{ ref("fct_complaints") }}) as fact_rows,
        (select sum(complaints) from {{ ref("mart_monthly_compliance") }}) as monthly,
        (select sum(complaints) from {{ ref("mart_municipality_summary") }}) as by_municipality
)

select *
from totals
where monthly != fact_rows or by_municipality != fact_rows
