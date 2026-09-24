/*
    This macro get the CDP transaction:
    - Insert (I)
    - Update (U)

    If the process if incremental, get the transaction
    based on the hash column.

    If the process is not incremental, use by default I.
*/
{% macro get_cdp_transaction(alias_stg, hash_col, keys) %} -- noqa: LT02

    {% if is_incremental() %}
        CASE
            /* Case the row exists in both tables and hash is diferent, so U */
            WHEN
                {{ this }}.{{ hash_col }} != {{ alias_stg }}.{{ hash_col }}
                /* Apply to each key column*/
                {% for col_key in keys %}
                    AND {{ this }}.{{ col_key }} IS NOT NULL
                {% endfor %}
                    THEN 'U'
            /* Case the row exists just in the stage table, so I */
            WHEN
                {{ this }}.{{ hash_col }} IS NULL
                {% for col_key in keys %}
                    AND {{ this }}.{{ col_key }} IS NULL
                    AND {{ alias_stg }}.{{ col_key }} IS NOT NULL
                {% endfor %}
                    THEN 'I'
            /* Otherwise N/A */
            ELSE 'N/A'
        END AS CDP_TRANSACTION
    {% else %}
        'I' AS CDP_TRANSACTION
    {% endif %}

{% endmacro %}
