-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item', 'location', 'day', 'company'
] %}
{% set list_another_columns = [
    'blockedquantity', 'onhandquantity', 'quarantinequantity',
    'uom', 'cutoffquantity'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_onhands'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('onhands_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
    "{{ update_control_unload_ts(this, 'post_hook') }}"
] %}

{{
    config(
        materialized = 'table',
        unique_key = list_keys,
        tags = list_tags,
        pre_hook = list_pre_hooks,
        post_hook = list_post_hooks
    )
}}

WITH
ONHANDS AS (
    SELECT
        ONHANDS_STG.ITEM,
        ONHANDS_STG.LOCATION,
        ONHANDS_STG.DAY,
        ONHANDS_STG.COMPANY,
        ONHANDS_STG.BLOCKEDQUANTITY,
        ONHANDS_STG.ONHANDQUANTITY,
        ONHANDS_STG.QUARANTINEQUANTITY,
        ONHANDS_STG.CUTOFFQUANTITY,
        ONHANDS_STG.UOM,
        ONHANDS_STG.HASH_ID,
        {{ get_cdp_transaction('ONHANDS_STG', 'HASH_ID', list_keys) }}
    FROM {{ ref('onhands_master') }} AS ONHANDS_STG
    /* If incemental apply macro */
    {{ set_incremental_strategy('ONHANDS_STG', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='OnHands') }}
FROM ONHANDS
