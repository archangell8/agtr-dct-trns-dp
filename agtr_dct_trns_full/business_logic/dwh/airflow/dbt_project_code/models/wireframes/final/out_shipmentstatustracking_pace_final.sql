-- noqa: disable=all
{% set keys = [
    'item', 'source', 'version_name', 'location', 'transmode', 'operation_type',
    'status', 'carrier', 'day'
    ]
%}

{%
    set another_columns = [
    'shipment_qty_intermediate_wf06b', 'pace_intermediate_wf06b',
    'number_of_shipments_intermediate_wf06b'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_shipmentstatustracking_pace', ref('out_shipmentstatustracking_pace'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_shipmentstatustracking_pace') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf06'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.ITEM,
        S.SOURCE,
        S.LOCATION,
        S.TRANSMODE,
        S.OPERATION_TYPE,
        S.STATUS,
        S.CARRIER,
        S.DAY,
        S.SHIPMENT_QTY_INTERMEDIATE_WF06B,
        S.PACE_INTERMEDIATE_WF06B,
        S.NUMBER_OF_SHIPMENTS_INTERMEDIATE_WF06B,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_shipmentstatustracking_pace', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_shipmentstatustracking_pace') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}

)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_shipmentstatustracking_pace') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}