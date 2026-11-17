{% macro refuse_prod_outside_github_actions(target_name=target.name) %}
    {#- Only the Pipeline workflow on main writes prod. A laptop develops against dev. -#}
    {%- if target_name == "prod" and env_var("GITHUB_ACTIONS", "") != "true" -%}
        {{ exceptions.raise_compiler_error(
            "The prod target is built only by the Pipeline workflow on main. Use --target dev."
        ) }}
    {%- endif -%}
{% endmacro %}
