{% macro latest_complete_release(relation) %}
    {#-
        raw keeps every release, and a load that failed halfway can leave rows behind without
        appearing in _dlt_loads (docs/adr/0003-raw-ingestion.md). Read only finished loads and,
        of those, the latest release.
    -#}
    select *
    from {{ relation }}
    where _dlt_load_id in (
        select load_id from {{ source("dlt", "_dlt_loads") }} where status = 0
    )
    qualify _release_at = max(_release_at) over ()
{% endmacro %}
