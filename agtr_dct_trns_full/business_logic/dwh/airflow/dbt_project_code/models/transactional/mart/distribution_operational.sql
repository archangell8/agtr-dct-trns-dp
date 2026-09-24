-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'itemid', 'sourceid', 'transmode', 'finaldestinationid', 'day',
    'operator', 'operationtype'
] %}
{% set list_another_columns = [
    'plannedquantity', 'uom'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'Distribution_Operational') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('distribution_operational_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
    ) %}
{% endif %}

--update_control_unload_ts has to be the last post_hook
{% do list_post_hooks.append(
    "{{ update_control_unload_ts(this, 'post_hook') }}"
) %}


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
DISTRIBUTION_OPERATIONAL AS (
    SELECT
        S.ITEMID,
        S.SOURCEID,
        S.TRANSMODE,
        S.FINALDESTINATIONID,
        S.DAY,
        S.OPERATOR,
        S.OPERATIONTYPE,
        S.PLANNEDQUANTITY,
        S.UOM,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('distribution_operational_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='Distribution_Operational') }}
FROM DISTRIBUTION_OPERATIONAL
