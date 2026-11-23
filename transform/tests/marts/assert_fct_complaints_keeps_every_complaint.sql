-- The fact table must have exactly one row per staged complaint: a join that drops or repeats
-- complaints would shift every rate built on it.
with counts as (
    select
        (select count(*) from {{ ref("stg_car__complaints") }}) as staged,
        (select count(*) from {{ ref("fct_complaints") }}) as modeled
)

select
    staged,
    modeled
from counts
where staged != modeled
