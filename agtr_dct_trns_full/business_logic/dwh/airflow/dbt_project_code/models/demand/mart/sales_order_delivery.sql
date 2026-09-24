-- noqa: disable=all
{% set list_keys = [
    'demandid'
] %}
{% set list_another_columns = [
        'item', 'location', 'customerid', 'shipto', 'referenceport',
        'deliveredsalesorderquantity', 'committedsalesorderquantity',
        'creationdateofsalesorderdocument',
        'salesordercommitdate', 'lastchangeddateofsalesorder', 'uom',
        'ordersalesforce', 'lta', 'blockedquantity', 'freighttype',
        'sourcebp', 'availablequantity', 'blockingtype', 'status',
        'transmode', 'operationtype', 'cmm_shipto_address'
    ]
%}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'SalesOrderDelivery') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('sales_order_delivery_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
    ) %}
{% endif %}

--update_control_unload_ts has to be the last post_hook
{% do list_post_hooks.append(
    "{{ update_control_unload_ts(this, 'post_hook') }}"
) %}


{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = list_keys,
        tags = list_tags,
        pre_hook = list_pre_hooks,
        post_hook = list_post_hooks
    )
}}

WITH
SALES_ORDER_DELIVERY AS (
    SELECT
        S.DEMANDID,
        S.ITEM,
        S.LOCATION,
        S.SOURCEBP,
        S.CUSTOMERID,
        S.SHIPTO,
        S.REFERENCEPORT,
        S.DELIVEREDSALESORDERQUANTITY,
        S.COMMITTEDSALESORDERQUANTITY,
        S.CREATIONDATEOFSALESORDERDOCUMENT,
        S.SALESORDERCOMMITDATE,
        S.LASTCHANGEDDATEOFSALESORDER,
        S.FREIGHTTYPE,
        S.BLOCKEDQUANTITY,
        S.UOM,
        S.ORDERSALESFORCE,
        S.LTA,
        S.AVAILABLEQUANTITY,
        S.BLOCKINGTYPE,
        S.STATUS,
        S.TRANSMODE,
        S.OPERATIONTYPE,
        S.CMM_SHIPTO_ADDRESS,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('sales_order_delivery_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='SalesOrderDelivery') }}
FROM SALES_ORDER_DELIVERY

{% if check_model_group_scheduler(list_tags, 'SalesOrderDelivery') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}

