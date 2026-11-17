with release as (
    {{ latest_complete_release(source("car", "car_complaints")) }}
),

renamed as (
    -- Not carried over, because they repeat other columns with no disagreement in the release
    -- of 2026-11-10: a_o and mes (the filing date) and color_estado (VERDE is on time).
    select
        cast(item as int64) as complaint_id,
        -- Published as ISO timestamps whose time is always midnight.
        cast(left(fecha_radicaci_n, 10) as date) as filed_on,
        cast(left(fecha_vencimiento, 10) as date) as due_on,
        cast(left(fecha_respuesta_final, 10) as date) as answered_on,
        {{ clean_text("tipo_petici_n") }} as petition_type,
        {{ clean_text("canal") }} as channel,
        {{ clean_text("usuario") }} as filer,
        {{ clean_text("tipo_persona") }} as filer_type,
        {{ clean_text("atenci_n_preferencial") }} as preferential_attention,
        {{ clean_text("dependencia_principal") }} as regional_office,
        {{ clean_text("municipio") }} as municipality_name,
        {{ clean_text("vereda") }} as vereda,
        {{ clean_text("tema") }} as theme,
        {{ clean_text("agua") }} as water_mark,
        {{ clean_text("aire") }} as air_mark,
        {{ clean_text("fauna") }} as fauna_mark,
        {{ clean_text("flora") }} as flora_mark,
        {{ clean_text("suelo") }} as soil_mark,
        {{ clean_text("riesgo_salud_u_otros") }} as health_risk,
        {{ clean_text("proceso_especial") }} as special_process,
        {{ clean_text("visita") }} as site_visit,
        {{ clean_text("visita_existencia_afectacion") }} as visit_found_impact,
        {{ clean_text("tipo_respuesta") }} as answer_type,
        {{ clean_text("estado_respuesta") }} as answer_status,
        {{ clean_text("estado_actual") }} as current_status,
        {{ clean_text("finaliz_en") }} as closed_with,
        {{ clean_text("serie") }} as records_series,
        {{ clean_text("subserie") }} as records_subseries,
        _release_at as released_at
    from release
)

-- Coded values are decoded here. Their raw values are checked with accepted_values on the
-- source, so a new code fails the build instead of turning into null.
select
    complaint_id,
    filed_on,
    due_on,
    answered_on,
    petition_type,
    channel,
    filer,
    filer_type,
    -- CAR writes "not applicable" both with and without brackets.
    if(preferential_attention = '[No Aplica]', 'No Aplica', preferential_attention)
        as preferential_attention,
    regional_office,
    municipality_name,
    vereda,
    theme,
    -- A resource is marked with X. Most complaints have none marked (almost none before 2014),
    -- so an unmarked resource is unknown, not a "no".
    if(water_mark = 'X', true, null) as concerns_water,
    if(air_mark = 'X', true, null) as concerns_air,
    if(fauna_mark = 'X', true, null) as concerns_fauna,
    if(flora_mark = 'X', true, null) as concerns_flora,
    if(soil_mark = 'X', true, null) as concerns_soil,
    -- N.A means the risk was not assessed.
    case health_risk when 'SI' then true when 'NO' then false end as poses_health_risk,
    if(special_process = '[No Aplica]', 'No Aplica', special_process) as special_process,
    case site_visit when 'SI' then true when 'NO' then false end as had_site_visit,
    -- Stays text: besides SI and NO, inspectors answered DUDA.
    visit_found_impact,
    answer_type,
    -- CAR's own label, which agrees in every row with answered_on <= due_on.
    case answer_status
        when 'Respuesta en Terminos' then true
        when 'Respuesta Fuera de Terminos' then false
    end as is_on_time_per_car,
    current_status,
    closed_with,
    records_series,
    records_subseries,
    released_at
from renamed
