-- noqa: disable=all
{% set keys = [
    'type_of_cost',
    'reason'
    ]
%}

{%
    set another_columns = []
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_reasonmaster') }}"
] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['master'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.TYPE_OF_COST,
        S.REASON,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_reasonmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_reasonmaster') }} AS S
    /* If incremental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_reasonmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}
