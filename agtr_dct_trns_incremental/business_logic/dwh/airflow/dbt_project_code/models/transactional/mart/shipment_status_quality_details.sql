-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'status', 'shipmentid', 'measure'
] %}
{% set list_another_columns = [
    'statusreferencedate', 'bk', 'uom', 'quantity',
    'value', 'unit', 'statusqualityreferencedate'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'ShipmentStatusQualityDetails') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('shipment_status_quality_details_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
    ) %}
    {% do list_post_hooks.append(
        "{{ update_timestamp_inc_old_shipments('shipment_status_quality_details', 1) }}"
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
SHIPMENT_STATUS AS (
    SELECT
    	SHIPMENT_STG.SHIPMENTID,
        SHIPMENT_STG.STATUS,
        SHIPMENT_STG.STATUSREFERENCEDATE,
        SHIPMENT_STG.QUANTITY,
        SHIPMENT_STG.STATUSQUALITYREFERENCEDATE,
        SHIPMENT_STG.MEASURE,
        SHIPMENT_STG.VALUE,
        SHIPMENT_STG.UNIT,
        SHIPMENT_STG.BK,
        SHIPMENT_STG.UOM,
        SHIPMENT_STG.HASH_ID,
        {{ get_cdp_transaction('SHIPMENT_STG', 'HASH_ID', list_keys) }}
    FROM {{ ref('shipment_status_quality_details_master') }} AS SHIPMENT_STG
    /* If incemental apply macro */
    {{ set_incremental_strategy('SHIPMENT_STG', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='ShipmentStatusQualityDetails') }}
FROM SHIPMENT_STATUS

{% if check_model_group_scheduler(list_tags, 'ShipmentStatusQualityDetails') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
