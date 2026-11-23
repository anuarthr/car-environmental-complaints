select
    theme,
    resource
from {{ ref("car_theme_resources") }}
