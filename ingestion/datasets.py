"""The datasets the pipeline loads from datos.gov.co and the columns each one must publish."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Dataset:
    """A Socrata dataset, the raw table it lands in and the columns it is expected to publish."""

    id: str
    table: str
    columns: tuple[str, ...]


# Field names as the API publishes them. Socrata replaces accented letters with underscores, so
# fecha_radicaci_n is "fecha radicación" and a_o is "año". Staging gives them readable names.
CAR_COMPLAINTS = Dataset(
    id="5ddb-j9e9",
    table="car_complaints",
    columns=(
        "item",
        "fecha_radicaci_n",
        "a_o",
        "mes",
        "tipo_petici_n",
        "canal",
        "usuario",
        "fecha_vencimiento",
        "tipo_respuesta",
        "fecha_respuesta_final",
        "dependencia_principal",
        "color_estado",
        "estado_respuesta",
        "municipio",
        "vereda",
        "finaliz_en",
        "visita",
        "visita_existencia_afectacion",
        "suelo",
        "flora",
        "fauna",
        "aire",
        "agua",
        "serie",
        "subserie",
        "estado_actual",
        "tipo_persona",
        "atenci_n_preferencial",
        "riesgo_salud_u_otros",
        "proceso_especial",
        "tema",
    ),
)

# DANE's municipality codes, used only as a reference table to place CAR's municipality names.
DIVIPOLA_MUNICIPALITIES = Dataset(
    id="gdxc-w37w",
    table="divipola_municipalities",
    columns=("cod_dpto", "dpto", "cod_mpio", "nom_mpio", "tipo_municipio", "longitud", "latitud"),
)

DATASETS = (CAR_COMPLAINTS, DIVIPOLA_MUNICIPALITIES)
