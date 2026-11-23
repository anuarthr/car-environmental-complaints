with complaints as (
    select
        complaints.municipality_code,
        themes.resource,
        complaints.is_on_time_per_car,
        complaints.answered_within_legal_term
    from {{ ref("fct_complaints") }} as complaints
    left join {{ ref("dim_theme") }} as themes
        on complaints.theme = themes.theme
),

-- Complaints with no municipality are grouped under a null code instead of dropped, so the
-- mart adds up to every complaint and the map's gap stays visible.
counted as (
    select
        municipality_code,
        resource,
        count(*) as complaints,
        countif(is_on_time_per_car) as answered_on_time_per_car,
        countif(answered_within_legal_term is not null) as judged_against_legal_term,
        countif(answered_within_legal_term) as answered_within_legal_term
    from complaints
    group by municipality_code, resource
)

select
    counted.municipality_code,
    municipalities.municipality_name,
    municipalities.department_name,
    municipalities.latitude,
    municipalities.longitude,
    counted.resource,
    counted.complaints,
    counted.answered_on_time_per_car,
    counted.judged_against_legal_term,
    counted.answered_within_legal_term
from counted
left join {{ ref("dim_municipality") }} as municipalities
    on counted.municipality_code = municipalities.municipality_code
