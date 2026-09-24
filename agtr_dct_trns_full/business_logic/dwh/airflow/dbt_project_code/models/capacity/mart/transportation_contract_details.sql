-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'transportationcontractid', 'transportationcontractlineid', 'startdate', 'enddate'
] %}
{% set list_another_columns = [
    'mintolerance', 'source', 'destination', 'itemid',
    'penaltyfee', 'transmode', 'quantity', 'toprate',
    'uom', 'comments', 'paidpenalty', 'currency'
] %}
{% set list_tags = [
    'model_mart', 'delta_full'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('transportation_contract_details_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
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
TRANSPORTATION_CONTACT AS (
    SELECT
        S.TRANSPORTATIONCONTRACTID,
        S.TRANSPORTATIONCONTRACTLINEID,
        S.MINTOLERANCE,
        S.SOURCE,
        S.DESTINATION,
        S.ITEMID,
        S.PENALTYFEE,
        S.TRANSMODE,
        S.STARTDATE,
        S.ENDDATE,
        S.QUANTITY,
        S.TOPRATE,
        S.UOM,
        S.COMMENTS,
        S.PAIDPENALTY,
        S.CURRENCY,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('transportation_contract_details_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='TransportationContractDetails') }}
FROM TRANSPORTATION_CONTACT
