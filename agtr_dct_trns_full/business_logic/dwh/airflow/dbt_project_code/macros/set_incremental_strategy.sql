/*
    This macro builds logic to capture only new process records
    from the staging table.

    Example:
        LEFT JOIN <database>.<schema>.my_model
            ON 1 = 1
            AND my_model.key1 = vw_my_model_stg.key1
            AND my_model.key2 = vw_my_model_stg.key2
        WHERE
            1 = 1
            AND (
                my_model.hash_id != vw_my_model_stg.hash_id
                OR my_model.key1 IS NULL
                OR my_model.key2 IS NULL
            )

*/
{% macro set_incremental_strategy(alias_stg, hash_col, keys) %}

    {% if is_incremental() %}

        LEFT JOIN {{ this }}
            ON 1 = 1
            {% for col_key in keys %}
            AND {{ this }}.{{ col_key }} = {{ alias_stg }}.{{ col_key }} -- noqa
            {% endfor %}
        WHERE
            1 = 1
            AND (
                {{ this }}.{{ hash_col }} != {{ alias_stg }}.{{ hash_col }} -- noqa
                {% for col_key in keys %}
                OR {{ this }}.{{ col_key }} IS NULL -- noqa
                {% endfor %}
            )

    {% endif %}

{% endmacro %}
