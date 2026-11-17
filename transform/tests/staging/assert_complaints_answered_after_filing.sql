-- An answer cannot come before the complaint it answers. The release of 2026-11-10 has 198 such
-- rows. They are CAR's recording errors: staging keeps them as published and this test reports
-- them.
{{ config(severity="warn") }}

select
    complaint_id,
    filed_on,
    answered_on
from {{ ref("stg_car__complaints") }}
where answered_on < filed_on
