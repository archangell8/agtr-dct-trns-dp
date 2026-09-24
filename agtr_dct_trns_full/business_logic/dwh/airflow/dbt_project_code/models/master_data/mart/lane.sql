-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'laneid'
] %}
{% set list_another_columns = [
    'location_from', 'location_to', 'transmode', 'lane_description',
    'location_from_unit_structure', 'location_to_unit_structure',
    'islane_optimizable'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'Lane') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('lane_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
LANE AS (
    SELECT
        S.LANEID,
        S.LOCATION_FROM,
        S.LOCATION_TO,
        S.TRANSMODE,
        S.LANE_DESCRIPTION,
        S.LOCATION_FROM_UNIT_STRUCTURE,
        S.LOCATION_TO_UNIT_STRUCTURE,
        S.ISLANE_OPTIMIZABLE,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('lane_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='Lane') }}
FROM LANE

{% if check_model_group_scheduler(list_tags, 'Lane') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
