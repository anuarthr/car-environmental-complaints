with release as (
    {{ latest_complete_release(source("dane", "divipola_municipalities")) }}
)

select
    -- DANE codes are identifiers with leading zeros (05001 is Medellín), so they stay text.
    cod_mpio as municipality_code,
    {{ clean_text("nom_mpio") }} as municipality_name,
    {{ clean_text("tipo_municipio") }} as municipality_type,
    cod_dpto as department_code,
    {{ clean_text("dpto") }} as department_name,
    -- Published with a decimal comma.
    cast(replace(latitud, ',', '.') as float64) as latitude,
    cast(replace(longitud, ',', '.') as float64) as longitude,
    _release_at as released_at
from release
