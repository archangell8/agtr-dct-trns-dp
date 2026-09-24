-- noqa: disable=all
{% set keys = [
    'version_name', 'demandid'
    ]
%}

{%
    set another_columns = [
        'warehousesalesorders'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_warehousesalesorders', ref('out_warehousesalesorders'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_warehousesalesorders') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf_warehousesalesorders'],
        post_hook = list_post_hooks
    )
}}

WITH FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.DEMANDID,
        S.WAREHOUSESALESORDERS,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_warehousesalesorders', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_warehousesalesorders') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_warehousesalesorders') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}