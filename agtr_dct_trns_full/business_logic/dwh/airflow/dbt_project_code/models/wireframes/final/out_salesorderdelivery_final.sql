-- noqa: disable=all
{% set keys = [
    'version_name', 'item', 'location', 'demandid', 'customer', 'demand_type',
    'operation_type', 'day'
    ]
%}

{%
    set another_columns = [
    'sales_channel', 'so_committed_date', 'so_delivery_date',
    'so_last_updated_date','so_document_creation_date', 'so_delivered_qty',
    'so_committed_qty','lta', 'quantity_gap', 'so_blocked_qty'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_salesorderdelivery', ref('out_salesorderdelivery'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_salesorderdelivery') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf43'],
        post_hook = list_post_hooks
    )
}}

WITH FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.ITEM,
        S.LOCATION,
        S.DEMANDID,
        S.CUSTOMER,
        S.DEMAND_TYPE,
        S.OPERATION_TYPE,
        S.DAY,
        S.SALES_CHANNEL,
        S.SO_LAST_UPDATED_DATE,
        S.SO_DOCUMENT_CREATION_DATE,
        S.SO_DELIVERED_QTY,
        S.SO_COMMITTED_QTY,
        S.SO_COMMITTED_DATE,
        S.SO_DELIVERY_DATE,
        S.LTA,
        S.QUANTITY_GAP,
        S.SO_BLOCKED_QTY,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_salesorderdelivery', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_salesorderdelivery') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_salesorderdelivery') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}