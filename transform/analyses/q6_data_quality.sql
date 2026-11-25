-- Question 6: what in the release cannot be taken at face value. One row per issue, with the
-- complaints it touches in the latest release.
select
    issue,
    complaints,
    round(100 * complaints / (select count(*) from {{ ref("fct_complaints") }}), 2) as pct
from (
    select
        countif(complaints.is_answered_before_filing) as answered_before_filing,
        countif(complaints.is_due_before_filing) as due_before_filing,
        countif(complaints.due_on > date(complaints.released_at)) as due_after_release,
        countif(complaints.municipality_code is null) as no_municipality,
        countif(starts_with(upper(complaints.car_municipality_name), 'LOC'))
            as bogota_district_as_municipality,
        countif(themes.resource is null) as theme_names_no_resource,
        countif(themes.resource = 'several') as theme_names_several_resources,
        countif(complaints.channel = 'APLICAR') as channel_aplicar,
        countif(complaints.poses_health_risk is null) as health_risk_not_assessed,
        countif(complaints.had_site_visit is null) as site_visit_not_recorded
    from {{ ref("fct_complaints") }} as complaints
    left join {{ ref("dim_theme") }} as themes on complaints.theme = themes.theme
)
unpivot (
    complaints for issue in (
        answered_before_filing,
        due_before_filing,
        due_after_release,
        no_municipality,
        bogota_district_as_municipality,
        theme_names_no_resource,
        theme_names_several_resources,
        channel_aplicar,
        health_risk_not_assessed,
        site_visit_not_recorded
    )
)
order by complaints desc
