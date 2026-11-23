with complaints as (
    select * from {{ ref("stg_car__complaints") }}
),

deadlines as (
    select * from {{ ref("int_complaints__deadlines") }}
),

municipality_codes as (
    select
        car_municipality_name,
        municipality_code
    from {{ ref("car_municipality_codes") }}
)

-- Both lookups have one row per key (tested as unique), so the left joins keep one row per
-- complaint, including those with no municipality.
select
    complaints.complaint_id,
    complaints.filed_on,
    complaints.due_on,
    complaints.answered_on,
    municipality_codes.municipality_code,
    complaints.municipality_name as car_municipality_name,
    complaints.vereda,
    complaints.theme,
    complaints.regional_office,
    complaints.channel,
    complaints.petition_type,
    complaints.filer_type,
    complaints.preferential_attention,
    complaints.special_process,
    complaints.poses_health_risk,
    complaints.had_site_visit,
    complaints.visit_found_impact,
    complaints.answer_type,
    -- Parcial, Otra and Requerimiento leave the complaint open, so only a De Fondo answer
    -- counts as settling it.
    complaints.answer_type = 'De Fondo' as is_full_answer,
    complaints.current_status,
    complaints.closed_with,
    deadlines.calendar_days_to_due,
    deadlines.business_days_to_due,
    deadlines.calendar_days_to_answer,
    deadlines.business_days_to_answer,
    deadlines.legal_term_business_days,
    deadlines.legal_due_on,
    deadlines.due_matches_legal_term,
    complaints.is_on_time_per_car,
    deadlines.answered_within_legal_term,
    deadlines.answered_within_double_term,
    -- Recording errors kept as published; measures of time can filter them out.
    complaints.answered_on < complaints.filed_on as is_answered_before_filing,
    complaints.due_on < complaints.filed_on as is_due_before_filing,
    complaints.released_at
from complaints
left join deadlines
    on complaints.complaint_id = deadlines.complaint_id
left join municipality_codes
    on complaints.municipality_name = municipality_codes.car_municipality_name
