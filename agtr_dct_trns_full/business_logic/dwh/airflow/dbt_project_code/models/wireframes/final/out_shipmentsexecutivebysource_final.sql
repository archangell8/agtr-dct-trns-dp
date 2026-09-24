-- noqa: disable=all
{% set keys = [
    'version_name', 'item', 'source', 'transmode', 'transshipment',
    'operation_type', 'day', 'customer', 'location'
    ]
%}

{%
    set another_columns = [
    'actuals_qty_source', 'scheduled_qty_source'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_shipmentsexecutivebysource', ref('out_shipmentsexecutivebysource'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_shipmentsexecutivebysource') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf41b'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.ITEM,
        S.SOURCE,
        S.TRANSMODE,
        S.TRANSSHIPMENT,
        S.OPERATION_TYPE,
        S.DAY,
        S.CUSTOMER,
        S.LOCATION,
        S.ACTUALS_QTY_SOURCE,
        S.SCHEDULED_QTY_SOURCE,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_shipmentsexecutivebysource', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_shipmentsexecutivebysource') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_shipmentsexecutivebysource') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}