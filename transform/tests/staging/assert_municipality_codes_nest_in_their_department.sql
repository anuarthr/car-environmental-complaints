-- A DANE municipality code is five digits that start with its department's two. A code that
-- breaks this has lost its leading zero somewhere, and would match nothing in other sources.
select municipality_code, department_code
from {{ ref("stg_dane__municipalities") }}
where not regexp_contains(municipality_code, r'^\d{5}$')
   or not starts_with(municipality_code, department_code)
