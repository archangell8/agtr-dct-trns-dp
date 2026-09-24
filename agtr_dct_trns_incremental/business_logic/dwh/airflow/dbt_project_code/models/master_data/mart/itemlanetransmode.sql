-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'bodlaneid', 'transmode', 'itemid'
] %}
{% set list_another_columns = [
    'leadtime', 'lotsizemin'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'ItemLaneTransmode') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('itemlanetransmode_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
ITEM_LANE_TRANSMODE AS (
    SELECT
        S.BODLANEID,
        S.TRANSMODE,
        -- S.MODAL,
        S.ITEMID,
        S.LEADTIME,
        S.LOTSIZEMIN,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('itemlanetransmode_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='ItemLaneTransmode') }}
FROM ITEM_LANE_TRANSMODE

{% if check_model_group_scheduler(list_tags, 'ItemLaneTransmode') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
