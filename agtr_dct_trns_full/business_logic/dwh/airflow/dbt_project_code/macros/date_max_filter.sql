--noqa:disable=all
{% macro date_max_filter(field_name, format, null_or_na) %}
        {% do log('null_or_na ='~ null_or_na) %}
        (
            TRY_TO_DATE({{ field_name }}, '{{ format }}') <= DATEADD('YEAR', 20, CURRENT_DATE())
            OR
            {% if null_or_na == 'null' %}
                {{ field_name }} IS NULL
            {% else %}
                {{ field_name }} = 'N/A'
            {% endif %}
        )

{% endmacro %}
