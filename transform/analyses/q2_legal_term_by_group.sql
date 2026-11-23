-- Question 2: where CAR misses the legal term most often, by regional office, channel, filer
-- type and resource. Compliance rose and fell over the years, so a group with more old
-- complaints could look worse only because of its age mix: each rate is given for every year
-- and for 2023 to 2025 alone.
with complaints as (
    select
        complaints.filed_on >= '2023-01-01' as is_recent,
        complaints.answered_within_legal_term,
        complaints.regional_office,
        complaints.channel,
        complaints.filer_type,
        coalesce(themes.resource, 'none named') as resource_named
    from {{ ref("fct_complaints") }} as complaints
    left join {{ ref("dim_theme") }} as themes on complaints.theme = themes.theme
    -- Answers dated before filing cannot be judged against the legal term.
    where complaints.answered_within_legal_term is not null
),

-- One row per complaint and grouping, so a single scan measures every grouping.
long as (
    select
        groupings.grouping_name,
        groupings.group_value,
        complaints.is_recent,
        complaints.answered_within_legal_term
    from complaints
    cross join unnest([
        struct('regional office' as grouping_name, complaints.regional_office as group_value),
        struct('channel', complaints.channel),
        struct('filer type', complaints.filer_type),
        struct('resource', complaints.resource_named)
    ]) as groupings
)

select
    grouping_name,
    group_value,
    count(*) as complaints,
    round(100 * countif(not answered_within_legal_term) / count(*), 1) as pct_missed,
    countif(is_recent) as complaints_2023_2025,
    round(
        100 * countif(is_recent and not answered_within_legal_term) / nullif(countif(is_recent), 0),
        1
    ) as pct_missed_2023_2025
from long
group by grouping_name, group_value
order by grouping_name asc, pct_missed desc
