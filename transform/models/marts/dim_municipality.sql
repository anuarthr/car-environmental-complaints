-- Every DIVIPOLA municipality, so the dimension also serves a complaint a future release files
-- outside today's jurisdiction.
select
    municipality_code,
    municipality_name,
    municipality_type,
    department_code,
    department_name,
    latitude,
    longitude
from {{ ref("stg_dane__municipalities") }}
