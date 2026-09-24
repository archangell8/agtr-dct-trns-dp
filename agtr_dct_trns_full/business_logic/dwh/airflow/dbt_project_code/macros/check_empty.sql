{% macro check_empty(field_name) %}

        IFF(
            COALESCE(TRIM({{ field_name }}), '') = '',
            NULL,
            TRIM({{ field_name }})
        )

{% endmacro %}
