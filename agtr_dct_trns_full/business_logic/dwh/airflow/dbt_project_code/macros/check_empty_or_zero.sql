{% macro check_empty_or_zero(field_name) %}

        IFF(
            COALESCE(TRIM({{ field_name }}), '') IN ('', '0'),
            NULL,
            TRIM({{ field_name }})
        )

{% endmacro %}
