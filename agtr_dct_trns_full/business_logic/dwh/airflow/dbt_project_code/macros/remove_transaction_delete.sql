-- noqa: disable=all

-- This macro remove from table the records that does not exists anymore.

{% macro remove_transaction_delete(table_stg, keys) %}
    {% if is_incremental() %}
        DELETE FROM {{ this }} AS F
        WHERE
            1 = 1
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
