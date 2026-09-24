-- noqa: disable=all
{% set keys = [
    'uom'
    ]
%}

{%
    set another_columns = []
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_uommaster') }}"
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
        S.UOM,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_uommaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_uommaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_uommaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}