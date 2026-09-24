-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'date', 'vesselid', 'itemid'
] %}
{% set list_another_columns = [
    'loadedquantity', 'uom'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('actual_vessel_load_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
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
ACTUAL_VESSEL_LOAD AS (
    SELECT
        V.DATE,
        V.VESSELID,
        V.ITEMID,
        V.LOADEDQUANTITY,
        V.UOM,
        V.HASH_ID,
        {{ get_cdp_transaction('V', 'HASH_ID', list_keys) }}
    FROM {{ ref('actual_vessel_load_master') }} AS V
    /* If incemental apply macro */
    {{ set_incremental_strategy('V', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='ActualVesselLoad') }}
FROM ACTUAL_VESSEL_LOAD
