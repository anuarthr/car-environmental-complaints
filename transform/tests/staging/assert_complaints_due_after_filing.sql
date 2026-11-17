-- A deadline cannot fall before the complaint was filed. The release of 2026-11-10 has 30 such
-- rows. They are CAR's recording errors: staging keeps them as published and this test reports
-- them.
{{ config(severity="warn") }}

select complaint_id, filed_on, due_on
from {{ ref("stg_car__complaints") }}
where due_on < filed_on
