-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'location', 'item', 'day', 'measure'
] %}
{% set list_another_columns = [
    'value', 'unit'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_onhands'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'OnHandsQuality') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('onhands_quality_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
ONHANDS_QUALITY AS (
    SELECT
        OH_QUALITY.LOCATION,
        OH_QUALITY.ITEM,
        OH_QUALITY.DAY,
        OH_QUALITY.MEASURE,
        OH_QUALITY.VALUE,
        OH_QUALITY.UNIT,
        OH_QUALITY.HASH_ID,
        {{ get_cdp_transaction('OH_QUALITY', 'HASH_ID', list_keys) }}
    FROM {{ ref('onhands_quality_master') }} AS OH_QUALITY
    /* If incemental apply macro */
    {{ set_incremental_strategy('OH_QUALITY', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='OnHandsQuality') }}
FROM ONHANDS_QUALITY

{% if check_model_group_scheduler(list_tags, 'OnHandsQuality') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
