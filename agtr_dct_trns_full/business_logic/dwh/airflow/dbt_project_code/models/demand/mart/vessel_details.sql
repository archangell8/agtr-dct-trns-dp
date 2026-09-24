-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'itemid'
] %}
{% set list_another_columns = [
    'name', 'estimatedtimearrival', 'estimatedtimeberthing',
    'estimatedtimecompletion', 'laycanmin', 'laycanmax', 'charter',
    'location', 'demurragerate', 'despatchrate', 'buyer', 'destination',
    'plannedquantity', 'uom'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('vessel_details_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
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
VESSEL AS (
    SELECT DISTINCT
        V.ID,
        V.NAME,
        V.ESTIMATEDTIMEARRIVAL,
        V.ESTIMATEDTIMEBERTHING,
        V.ESTIMATEDTIMECOMPLETION,
        V.LAYCANMIN,
        V.LAYCANMAX,
        V.CHARTER,
        V.LOCATION,
        V.DEMURRAGERATE,
        V.DESPATCHRATE,
        V.BUYER,
        V.DESTINATION,
        V.ITEMID,
        V.PLANNEDQUANTITY,
        V.UOM,
        V.HASH_ID, --a
        {{ get_cdp_transaction('V', 'HASH_ID', list_keys) }}
    FROM {{ ref('vessel_details_master') }} AS V
    /* If incemental apply macro */
    {{ set_incremental_strategy('V', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='VesselDetails') }}
FROM VESSEL
