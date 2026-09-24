{% macro check_execution_time_window(start_time, end_time) %}
    /* Check if the current_time is present on defined interval */
    {% if is_incremental() %} -- noqa

        AND TO_TIME(
            CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP())
        ) >= '{{ start_time }}'
        AND TO_TIME(
            CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP())
        ) < '{{ end_time }}'

    {% endif %}

{% endmacro %}
