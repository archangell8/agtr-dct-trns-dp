-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'locationid'
] %}
{% set list_another_columns = [
    'location_unit_structure', 'location_group', 'location_country',
    'location_region', 'location_sub_region', 'location_name',
    'location_code', 'zip', 'address', 'city', 'longitude',
    'latitude', 'state', 'location_ownership', 'operator',
    'location_ibp_asset', 'isactive', 'restriction', 'routingcomments',
    'location_type'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution', 'delta_onhands', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'Location') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('location_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
LOCATION_FINAL AS (
    SELECT
        S.LOCATIONID,
        S.LOCATION_UNIT_STRUCTURE,
        S.LOCATION_GROUP,
        S.LOCATION_COUNTRY,
        S.LOCATION_REGION,
        S.LOCATION_SUB_REGION,
        S.LOCATION_NAME,
        S.LOCATION_CODE,
        S.ZIP,
        S.ADDRESS,
        S.ISACTIVE,
        S.CITY,
        S.LONGITUDE,
        S.LATITUDE,
        S.STATE,
        S.LOCATION_OWNERSHIP,
        S.OPERATOR,
        S.LOCATION_IBP_ASSET,
        S.ROUTINGCOMMENTS,
        S.RESTRICTION,
        S.LOCATION_TYPE,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('location_master') }} AS S

    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='Location') }}
FROM LOCATION_FINAL

{% if check_model_group_scheduler(list_tags, 'Location') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
