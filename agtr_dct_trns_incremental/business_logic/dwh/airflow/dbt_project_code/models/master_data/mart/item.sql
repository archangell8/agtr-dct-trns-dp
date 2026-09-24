-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item'
] %}
{% set list_another_columns = [
    'itemname', 'itemstatus', 'itemclass', 'itemstage', 'item_type', 'l1', 'l2',
    'l3', 'baseuom', 'baseuomdescription', 'resource', 'containersize',
    'packagesize'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution', 'delta_onhands', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('item_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
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
ITEM AS (
    SELECT
        S.ITEM,
        S.ITEMNAME,
        S.ITEMSTATUS,
        S.ITEMCLASS,
        S.ITEMSTAGE,
        S.ITEM_TYPE,
        S.L1,
        S.L2,
        S.L3,
        S.BASEUOM,
        S.BASEUOMDESCRIPTION,
        S.RESOURCE,
        S.CONTAINERSIZE,
        S.PACKAGESIZE,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('item_master') }} AS S

    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='Item') }}
FROM ITEM
