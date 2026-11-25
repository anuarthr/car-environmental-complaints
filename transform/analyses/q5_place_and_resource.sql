-- Question 5: where complaints concentrate, and which resource they concern. Municipalities
-- ranked by complaints, with their share of the complaints that have a place, the running
-- share down the ranking, and one column per resource.
with by_municipality as (
    select *
    from (
        select
            municipality_code,
            municipality_name,
            department_name,
            coalesce(resource, 'none_named') as resource_named,
            complaints
        from {{ ref("mart_municipality_summary") }}
        where municipality_code is not null
    )
    pivot (
        sum(complaints) for resource_named in (
            'water', 'air', 'fauna', 'flora', 'soil', 'several', 'none_named'
        )
    )
),

totals as (
    select
        *,
        coalesce(water, 0) + coalesce(air, 0) + coalesce(fauna, 0) + coalesce(flora, 0)
        + coalesce(soil, 0) + coalesce(several, 0) + coalesce(none_named, 0) as complaints
    from by_municipality
)

select
    rank() over (order by complaints desc) as complaints_rank,
    municipality_name,
    department_name,
    complaints,
    round(100 * complaints / sum(complaints) over (), 1) as pct_of_placed,
    round(
        100 * sum(complaints) over (order by complaints desc, municipality_code asc)
        / sum(complaints) over (),
        1
    ) as cumulative_pct,
    water,
    air,
    fauna,
    flora,
    soil,
    several,
    none_named
from totals
order by complaints_rank, municipality_name
