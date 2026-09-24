-- noqa: disable=all
{% set keys = [
    'contractlineid', 'enddate'
    ]
%}

{%
    set another_columns = [
        'status', 'fiscalcondition', 'type', 'paymentdetails',
        'freighttype', 'destination', 'cancelled', 'received', 'balance',
        'contractid', 'contract_status', 'transmode', 'override_delivery_rate_ton',
        'delivery', 'total_qty_ton', 'received_qty_ton', 'to_receive_total_ton',
        'to_receive_flat_ton', 'to_receive_paf_ton', 'cancelled_qty_ton', 'currency',
        'freight_cost', 'planned_cost_bogey', 'actual_cost', 'actual_vs_freight',
        'actual_vs_bogey', 'available_qty_ton', 'blocked_qty_ton', 'salesrep',
        'harvest', 'id', 'contract_priority', 'quantity', 'purchased', 'contract_type',
        'all_contract', 'scheduling_status', 'sourcebp', 'farm', 'delivery_bp',
        'delivery_unit', 'item', 'pickup', 'producer', 'paymentdate', 'price',
        'freight', 'global_invoice', 'isslipwithchangeddestination', 'purchasedate'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_contractmaster') }}"
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
        S.CONTRACTLINEID,
        S.STATUS,
        S.FISCALCONDITION,
        S.TYPE,
        S.PAYMENTDETAILS,
        S.FREIGHTTYPE,
        S.DESTINATION,
        S.CANCELLED,
        S.RECEIVED,
        S.BALANCE,
        S.CONTRACTID,
        S.CONTRACT_STATUS,
        S.TRANSMODE,
        S.OVERRIDE_DELIVERY_RATE_TON,
        S.DELIVERY,
        S.TOTAL_QTY_TON,
        S.RECEIVED_QTY_TON,
        S.TO_RECEIVE_TOTAL_TON,
        S.TO_RECEIVE_FLAT_TON,
        S.TO_RECEIVE_PAF_TON,
        S.CANCELLED_QTY_TON,
        S.CURRENCY,
        S.FREIGHT_COST,
        S.PLANNED_COST_BOGEY,
        S.ACTUAL_COST,
        S.ACTUAL_VS_FREIGHT,
        S.ACTUAL_VS_BOGEY,
        S.AVAILABLE_QTY_TON,
        S.BLOCKED_QTY_TON,
        S.SALESREP,
        S.HARVEST,
        S.ID,
        S.CONTRACT_PRIORITY,
        S.QUANTITY,
        S.PURCHASED,
        S.CONTRACT_TYPE,
        S.ALL_CONTRACT,
        S.SCHEDULING_STATUS,
        S.SOURCEBP,
        S.FARM,
        S.DELIVERY_BP,
        S.DELIVERY_UNIT,
        S.ITEM,
        S.PICKUP,
        S.PRODUCER,
        S.STARTDATE,
        S.ENDDATE,
        S.PAYMENTDATE,
        S.PURCHASEDATE,
        S.PRICE,
        S.FREIGHT,
        S.GLOBAL_INVOICE,
        S.ISSLIPWITHCHANGEDDESTINATION,
        S.HASH_ID,
        S.HASH_KEY,
        -- In incremental process, receives 'TRUE' if a dimension has changed
        -- or its a new contractlineid
        {% if is_incremental() %}
            CASE
                WHEN (
                    {{ this }}.HASH_KEY != S.HASH_KEY
                    AND {{ this }}.CONTRACTLINEID IS NOT NULL
                ) OR {{ this }}.CONTRACTLINEID IS NULL
                        THEN 'TRUE'
            END AS DELTACHANGEFLAG,
        {% else %}
            NULL AS DELTACHANGEFLAG,
        {% endif %}
        {{ get_cdp_transaction_rearch('out_contractmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_contractmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_contractmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}