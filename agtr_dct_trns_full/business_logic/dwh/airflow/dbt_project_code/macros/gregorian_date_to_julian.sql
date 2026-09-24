{% macro gregorian_date_to_julian(alias, column) %}

(
    (
        YEAR({{ alias }}.{{ column }}) - 1900
    ) * 1000 + (
        DAYOFYEAR({{ alias }}.{{ column }})
    )
)

{% endmacro %}
