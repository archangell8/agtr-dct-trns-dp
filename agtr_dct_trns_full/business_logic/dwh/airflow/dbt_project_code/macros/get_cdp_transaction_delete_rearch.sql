-- noqa: disable=all

-- This macro set the delete flag (D) when the row exists on
-- the final table, but not exists on the stage table.
-- In add, this macro will be update all column to null, except the
-- key columns.

{% macro get_cdp_transaction_delete_rearch(model_name, table_stg, keys, another_columns) %}
    {% if is_incremental() %}
        {% set model = model_name | upper ~ "_FLAG" %}
        UPDATE
            {{ this }} AS F
        SET
            CDP_TRANSACTION = 'D',
            CDP_TIMESTAMP_INC = TO_CHAR(
                CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()),
                'YYYY-MM-DD HH24:MI:SS'
            ),
            {{ model }} = -1,
            HASH_ID = -999999 {% if another_columns %}, {% endif %}
            {% for col in another_columns %}
                {{ col }} = NULL{% if not loop.last %}, {% endif %}
            {% endfor %}
        WHERE CDP_TRANSACTION != 'D'
        AND NOT EXISTS (
            SELECT 1 FROM {{ table_stg }} S
            WHERE
                1 = 1
                {% for col_key in keys %}
                AND F.{{ col_key }} = S.{{ col_key }}
                {% endfor %}
        )
    {% endif %}
{% endmacro %}
