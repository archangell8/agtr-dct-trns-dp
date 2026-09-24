-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'shipmentid'
] %}
{% set list_another_columns = [
    'driver', 'penaltycost', 'currency', 'referencedate', 'type_of_cost',
    'reason', 'sub_reason'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'ShipmentPenalties') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('shipment_penalties_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
    ) %}
    {% do list_post_hooks.append(
        "{{ update_timestamp_inc_old_shipments('shipment_penalties', 1) }}"
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
SHIPMENT_PENALTIES AS (
    SELECT
        SHIPMENT_STG.ID,
        SHIPMENT_STG.SHIPMENTID,
        SHIPMENT_STG.DRIVER,
        SHIPMENT_STG.PENALTYCOST,
        SHIPMENT_STG.CURRENCY,
        SHIPMENT_STG.REFERENCEDATE,
        SHIPMENT_STG.TYPE_OF_COST,
        SHIPMENT_STG.REASON,
        SHIPMENT_STG.SUB_REASON,
        SHIPMENT_STG.HASH_ID,
        {{ get_cdp_transaction('SHIPMENT_STG', 'HASH_ID', list_keys) }}
    FROM {{ ref('shipment_penalties_master') }} AS SHIPMENT_STG
    /* If incemental apply macro */
    {{ set_incremental_strategy('SHIPMENT_STG', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='ShipmentPenalties') }}
FROM SHIPMENT_PENALTIES

{% if check_model_group_scheduler(list_tags, 'ShipmentPenalties') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
