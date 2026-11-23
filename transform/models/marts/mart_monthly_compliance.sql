-- Counts only, never rates: a rate for any period or group of offices is the ratio of the
-- summed counts, which an average of monthly rates would not give.
select
    date_trunc(filed_on, month) as filed_month,
    regional_office,
    count(*) as complaints,
    countif(is_on_time_per_car) as answered_on_time_per_car,
    countif(is_full_answer) as full_answers,
    countif(is_full_answer and is_on_time_per_car) as full_answers_on_time_per_car,
    countif(due_matches_legal_term) as due_on_legal_term,
    -- An answer dated before filing cannot be judged, so it stays out of the denominator.
    countif(answered_within_legal_term is not null) as judged_against_legal_term,
    countif(answered_within_legal_term) as answered_within_legal_term,
    countif(answered_within_double_term) as answered_within_double_term
from {{ ref("fct_complaints") }}
group by filed_month, regional_office
