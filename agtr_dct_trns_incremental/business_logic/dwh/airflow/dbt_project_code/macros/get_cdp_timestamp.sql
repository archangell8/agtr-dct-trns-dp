-- noqa: disable=all
{% macro get_cdp_timestamp(filename_o9) %}

    {% if is_incremental() %}
        NULL AS CDP_TIMESTAMP_FULL,
        TO_CHAR(
            CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()),
            'YYYY-MM-DD HH24:MI:SS'
        ) AS CDP_TIMESTAMP_INC,
    {% else %}
        TO_CHAR(
            CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()),
            'YYYY-MM-DD HH24:MI:SS'
        ) AS CDP_TIMESTAMP_FULL,
        NULL AS CDP_TIMESTAMP_INC,
    {% endif %}

    /* o9 timestamp column */
    CONCAT(
        '{{ filename_o9 }}',
        '_',
        TO_CHAR(
            CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()),
            'YYYYMMDDHH24MISS'
        )
    ) AS CDP_TIMESTAMP_O9
{% endmacro %}
