-- Question 4: do the recorded deadlines match the legal term? By filing year: how many fall
-- exactly 15 business days after filing, how many on the legal term in force (30 during the
-- pandemic decree), how many in the cluster of 41 to 48, and the most common value.
select
    extract(year from filed_on) as filed_year,
    count(*) as complaints,
    round(100 * countif(business_days_to_due = 15) / count(*), 1) as pct_at_15,
    round(100 * countif(due_matches_legal_term) / count(*), 1) as pct_at_legal_term,
    round(100 * countif(business_days_to_due between 41 and 48) / count(*), 1) as pct_at_41_48,
    round(100 * countif(business_days_to_due > legal_term_business_days) / count(*), 1)
        as pct_beyond_legal_term,
    approx_top_count(business_days_to_due, 1)[offset(0)].value as most_common_business_days
from {{ ref("fct_complaints") }}
where not is_due_before_filing
group by filed_year
order by filed_year
