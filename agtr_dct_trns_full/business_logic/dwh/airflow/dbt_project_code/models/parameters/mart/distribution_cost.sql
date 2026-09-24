-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'bodlane', 'month', 'item', 'currency'
] %}
{% set list_another_columns = [
    'disttransportationcostperunit'
] %}
{% set list_tags = [
    'model_mart', 'delta_full'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'DistributionCost') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('distribution_cost_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
DISTRIBUTION_COST AS (
    SELECT
        DIS.BODLANE,
        DIS.MONTH AS "MONTH",
        DIS.ITEM,
        DIS.CURRENCY,
        DIS.TRANSMODE,
        DIS.DISTTRANSPORTATIONCOSTPERUNIT,
        DIS.HASH_ID,
        {{ get_cdp_transaction('DIS', 'HASH_ID', list_keys) }}
    FROM {{ ref('distribution_cost_master') }} AS DIS
    /* If incemental apply macro */
    {{ set_incremental_strategy('DIS', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='DistributionCost') }}
FROM DISTRIBUTION_COST

{% if check_model_group_scheduler(list_tags, 'DistributionCost') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
