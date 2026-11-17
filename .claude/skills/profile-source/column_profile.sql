{#-
    One row per text column of a raw table, over the rows staging reads: complete loads only,
    latest release only. A single scan of the table, so it bills once.
-#}
{%- set relation = source(var("source"), var("table")) -%}
{%- set columns = [] -%}
{%- if execute -%}
    {%- for column in adapter.get_columns_in_relation(relation)
        if not column.name.startswith("_") and column.dtype == "STRING" -%}
        {%- do columns.append(column.name) -%}
    {%- endfor -%}
{%- endif -%}
{#- Matched against the bare form, so "[No Aplica]", "N.A" and "Sin datos." all count. -#}
{%- set marker = "r'^(sin\\b.*|no (aplica|verificad[oa]|registra|reporta|informa|sabe|tiene|disponible)\\b.*|n/?a|null|none|nan|ningun[oa]?|desconocid[oa]|s/?d|x|0|)$'" -%}

with complete_loads as (
    select load_id from {{ source("dlt", "_dlt_loads") }} where status = 0
),

latest_release as (
    select *
    from {{ relation }}
    where _dlt_load_id in (select load_id from complete_loads)
    qualify _release_at = max(_release_at) over ()
),

long as (
    select column_name, value
    from latest_release
    unpivot (value for column_name in ({{ columns | join(", ") or "missing_columns" }}))
),

value_counts as (
    select
        column_name,
        value,
        -- Lowercase, trimmed, without accents and with single spaces: two values that only
        -- differ in writing collapse into one.
        trim(regexp_replace(
            regexp_replace(normalize(lower(value), nfd), r'\p{M}', ''),
            r'[\s\x{00a0}]+', ' '
        )) as plain,
        count(*) as n
    from long
    group by column_name, value
),

shapes as (
    select
        *,
        regexp_contains(
            trim(regexp_replace(plain, r'[^\p{L}\p{N}/ ]', '')), {{ marker }}
        ) as is_marker
    from value_counts
),

variant_groups as (
    -- Spellings of one value: same plain form, different text.
    select
        column_name,
        array_agg(
            struct(plain, variants) order by total desc limit 10
        ) as variant_groups
    from (
        select
            column_name,
            plain,
            sum(n) as total,
            array_agg(struct(value, n) order by n desc) as variants
        from shapes
        group by column_name, plain
        having count(*) > 1
    )
    group by column_name
)

select
    shapes.column_name,
    sum(n) as row_count,
    count(*) as distinct_values,
    count(distinct plain) as distinct_plain,
    sum(if(is_marker, n, 0)) as marker_rows,
    array_agg(if(is_marker, struct(value, n), null) ignore nulls order by n desc limit 5)
        as markers,
    sum(if(value != trim(value), n, 0)) as untrimmed_rows,
    sum(if(strpos(value, ' ') > 0, n, 0)) as nbsp_rows,
    sum(if(regexp_contains(value, r'[\s\x{00a0}]{2,}'), n, 0)) as repeated_space_rows,
    min(length(value)) as min_length,
    max(length(value)) as max_length,
    round(sum(if(regexp_contains(value, r'^-?\d+$'), n, 0)) / sum(n), 4) as share_integer,
    round(sum(if(regexp_contains(value, r'^-?\d+[.,]\d+$'), n, 0)) / sum(n), 4) as share_decimal,
    round(sum(if(regexp_contains(value, r'^\d{4}-\d{2}-\d{2}'), n, 0)) / sum(n), 4) as share_iso_date,
    round(sum(if(plain in ('si', 'no'), n, 0)) / sum(n), 4) as share_yes_no,
    -- Complete when distinct_values is 15 or fewer.
    array_agg(struct(value, n) order by n desc limit 15) as top_values,
    any_value(variant_groups.variant_groups) as variant_groups
from shapes
left join variant_groups using (column_name)
group by shapes.column_name
order by shapes.column_name
