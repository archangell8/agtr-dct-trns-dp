{% macro julian_date_to_gregorian(alias, column) %}
    (
        DATEADD(
            DAY,
            SUBSTR(({{ alias }}.{{ column }}::INT + 1900000)::STRING, 5, 3)::INT - 1,
            TO_TIMESTAMP(
                CONCAT(SUBSTR(({{ alias }}.{{ column }}::INT + 1900000)::STRING, 1, 4), '01', '01'),
                'YYYYMMDD'
            )
        )
    )
{% endmacro %}
