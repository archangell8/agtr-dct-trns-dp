-- noqa: disable=all
{% macro set_agg_incremental_ts() %}

    {% if is_incremental() %}
        UPDATE
            {{ this }} AS F
        SET
            CDP_TIMESTAMP_INC = TO_CHAR(
                CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()),
                'YYYY-MM-DD HH24:MI:SS'
            )
        WHERE CDP_TIMESTAMP_INC IS NOT NULL
    {% endif %}

{% endmacro %}