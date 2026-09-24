-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'creditor', 'debitor', 'location', 'itemid', 'date'
] %}
{% set list_another_columns = [
    'quantity'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'PortSwap') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('port_swap_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
PORT_SWAP AS (
    SELECT
        V.CREDITOR,
        V.DEBITOR,
        V.LOCATION,
        V.ITEMID,
        V.DATE,
        V.QUANTITY,
        V.HASH_ID,
        {{ get_cdp_transaction('V', 'HASH_ID', list_keys) }}
    FROM {{ ref('port_swap_master') }} AS V
    /* If incemental apply macro */
    {{ set_incremental_strategy('V', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='PortSwap') }}
FROM PORT_SWAP

{% if check_model_group_scheduler(list_tags, 'PortSwap') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}

