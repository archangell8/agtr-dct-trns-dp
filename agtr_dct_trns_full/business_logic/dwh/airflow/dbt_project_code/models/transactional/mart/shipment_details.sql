-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'itemid'
] %}
{% set list_another_columns = [
    'operationtype', 'source', 'sourcebp', 'destination', 'loadnumber',
    'laneid', 'sourcingcontractid', 'transmode', 'carrier', 'vehicleid',
    'estimatedshipdate', 'actualshipdate', 'scheduleddate', 'arrivaldate',
    'estimateddeliverydate', 'actualdeliverydate', 'loadapplicationdate',
    'salesorderdeliveryid', 'finaldestination', 'pricetype', 'plannedcost',
    'actualcost', 'penaltycost', 'quantity', 'uom', 'currency', 'bk',
    'contract_number_applied', 'palletquantity', 'pallet', 'profile',
    'quality_adjustment'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'ShipmentDetails') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('shipment_details_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
    ) %}
    {% do list_post_hooks.append(
        "{{ update_timestamp_inc_old_shipments('shipment_details', 1) }}"
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
SHIPMENT AS (
    SELECT
        SHIP_STG.ID,
        SHIP_STG.OPERATIONTYPE,
        SHIP_STG.SOURCE,
        SHIP_STG.SOURCEBP,
        SHIP_STG.DESTINATION,
        SHIP_STG.LOADNUMBER,
        SHIP_STG.LANEID,
        SHIP_STG.SOURCINGCONTRACTID,
        SHIP_STG.TRANSMODE,
        SHIP_STG.CARRIER,
        SHIP_STG.VEHICLEID,
        SHIP_STG.ESTIMATEDSHIPDATE,
        SHIP_STG.ACTUALSHIPDATE,
        SHIP_STG.SCHEDULEDDATE,
        SHIP_STG.ARRIVALDATE,
        SHIP_STG.ESTIMATEDDELIVERYDATE,
        SHIP_STG.ACTUALDELIVERYDATE,
        SHIP_STG.LOADAPPLICATIONDATE,
        SHIP_STG.SALESORDERDELIVERYID,
        SHIP_STG.FINALDESTINATION,
        SHIP_STG.PALLET,
        SHIP_STG.PALLETQUANTITY,
        SHIP_STG.PROFILE,
        SHIP_STG.PRICETYPE,
        SHIP_STG.ITEMID,
        SHIP_STG.PLANNEDCOST,
        SHIP_STG.ACTUALCOST,
        SHIP_STG.PENALTYCOST,
        SHIP_STG.QUANTITY,
        SHIP_STG.UOM,
        SHIP_STG.CURRENCY,
        SHIP_STG.BK,
        SHIP_STG.CONTRACT_NUMBER_APPLIED,
        SHIP_STG.QUALITY_ADJUSTMENT,
        SHIP_STG.HASH_ID,
        {{ get_cdp_transaction('SHIP_STG', 'HASH_ID', list_keys) }}
    FROM {{ ref('shipment_details_master') }} AS SHIP_STG
    /* If incemental apply macro */
    {{ set_incremental_strategy('SHIP_STG', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='ShipmentDetails') }}
FROM SHIPMENT

{% if check_model_group_scheduler(list_tags, 'ShipmentDetails') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
