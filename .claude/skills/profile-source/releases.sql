{#-
    Rows of a raw table per release and per dlt load, and whether dlt finished each load.
    Staging reads only complete loads (status 0) of the latest release.
-#}
select
    data._release_at,
    data._dlt_load_id,
    loads.status as load_status,
    count(*) as row_count
from {{ source(var("source"), var("table")) }} as data
left join {{ source("dlt", "_dlt_loads") }} as loads
    on data._dlt_load_id = loads.load_id
group by data._release_at, data._dlt_load_id, loads.status
order by data._release_at, data._dlt_load_id
