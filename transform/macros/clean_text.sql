{% macro clean_text(column) %}
    {#-
        One space between words, none around them: some values separate words with a
        non-breaking space or repeat spaces, and would otherwise group apart from themselves.
        datos.gov.co publishes no empty cells, so an unknown value comes as a word: "Sin datos",
        and since CAR's release of 2026-11-10, "No verificado" for places nobody verified.
        Both become null in every column, so a release that starts using them elsewhere is
        already covered.
    -#}
    nullif(
        nullif(trim(regexp_replace({{ column }}, r'[\s\x{00a0}]+', ' ')), 'Sin datos'),
        'No verificado'
    )
{% endmacro %}
