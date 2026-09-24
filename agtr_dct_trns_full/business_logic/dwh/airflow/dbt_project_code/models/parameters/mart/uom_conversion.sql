-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item', 'uomfrom', 'uomto'
] %}
{% set list_another_columns = [
    'supplyplanningfinalconversionfactor'
] %}
{% set list_tags = [
    'model_mart', 'delta_full'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('uom_conversion_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
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
UOM AS (
    SELECT
        S.ITEM,
        S.UOMFROM,
        S.UOMTO,
        S.SUPPLYPLANNINGFINALCONVERSIONFACTOR,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('uom_conversion_master') }} AS S

    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='UOMConversion') }}
FROM UOM
