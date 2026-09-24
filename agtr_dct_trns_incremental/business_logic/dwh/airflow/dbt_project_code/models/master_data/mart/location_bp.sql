-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'bp_number'
] %}
{% set list_another_columns = [
    'bp_name', 'origin_subregion', 'origin_unit_name', 'origin_unit_id',
    'destination_unit_name', 'destination_unit_id', 'destination_ibge_id',
    'address_book', 'location_code', 'location_type', 'status',
    'origin_filial_expense'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('location_bp_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
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
LOCATION_BP AS (
    SELECT
        S.BP_NUMBER,
        S.BP_NAME,
        S.ORIGIN_SUBREGION,
        S.ORIGIN_UNIT_NAME,
        S.ORIGIN_UNIT_ID,
        S.DESTINATION_UNIT_NAME,
        S.DESTINATION_UNIT_ID,
        S.DESTINATION_IBGE_ID,
        S.ADDRESS_BOOK,
        S.LOCATION_CODE,
        S.STATUS,
        S.LOCATION_TYPE,
        S.ORIGIN_FILIAL_EXPENSE,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('location_bp_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='LocationBP') }}
FROM LOCATION_BP
