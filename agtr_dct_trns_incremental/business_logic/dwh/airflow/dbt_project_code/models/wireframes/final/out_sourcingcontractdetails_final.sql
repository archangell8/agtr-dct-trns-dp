-- noqa: disable=all
{% set keys = [
    'version_name', 'contract_lineid', 'item', 'supplier_location', 'source',
    'location', 'transmode', 'day', 'operation_type'
    ]
%}

{%
    set another_columns = [
        'freight_type', 'delivery_start_date', 'delivery_end_date',
        'delivery_status', 'sales_representative', 'contract_freight_cost',
        'actual_freight_cost', 'freight_cadence', 'plannedcost',
        'received_quantity', 'to_receive_total', 'to_receive_flat',
        'to_receive_paf', 'cancelled_quantity', 'paf_received_quantity',
        'balance_quantity', 'planned_quantity', 'loading_point_capacity'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_sourcingcontractdetails', ref('out_sourcingcontractdetails'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_sourcingcontractdetails') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf16b'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.CONTRACT_LINEID,
        S.ITEM,
        S.SUPPLIER_LOCATION,
        S.SOURCE,
        S.LOCATION,
        S.TRANSMODE,
        S.DAY,
        S.OPERATION_TYPE,
        S.FREIGHT_TYPE,
        S.DELIVERY_START_DATE,
        S.DELIVERY_END_DATE,
        S.DELIVERY_STATUS,
        S.SALES_REPRESENTATIVE,
        S.CONTRACT_FREIGHT_COST,
        S.ACTUAL_FREIGHT_COST,
        S.FREIGHT_CADENCE,
        S.PLANNEDCOST,
        S.RECEIVED_QUANTITY,
        S.TO_RECEIVE_TOTAL,
        S.TO_RECEIVE_FLAT,
        S.TO_RECEIVE_PAF,
        S.CANCELLED_QUANTITY,
        S.PAF_RECEIVED_QUANTITY,
        S.BALANCE_QUANTITY,
        S.PLANNED_QUANTITY,
        S.LOADING_POINT_CAPACITY,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_sourcingcontractdetails', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_sourcingcontractdetails') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_sourcingcontractdetails') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}