-- noqa: disable=all
{% set keys = [
    'location'
    ]
%}

{%
    set another_columns = [
        'location_zip', 'address', 'longitude', 'latitude', 'location_unit_structure',
        'location_group', 'location_country', 'location_region', 'location_sub_region',
        'location_code', 'city', 'location_state', 'location_ownership', 'location_operator',
        'location_ibp_asset', 'all_location', 'location_type', 'planning_location',
        'reporting_location', 'status', 'location_displayname', 'location_ibp_asset_displayname',
        'la1'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_locationmaster') }}"
] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['master'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.LOCATION,
        S.LOCATION_ZIP,
        S.ADDRESS,
        S.LONGITUDE,
        S.LATITUDE,
        S.LOCATION_UNIT_STRUCTURE,
        S.LOCATION_GROUP,
        S.LOCATION_COUNTRY,
        S.LOCATION_REGION,
        S.LOCATION_SUB_REGION,
        S.LOCATION_CODE,
        S.CITY,
        S.LOCATION_STATE,
        S.LOCATION_OWNERSHIP,
        S.LOCATION_OPERATOR,
        S.LOCATION_IBP_ASSET,
        S.ALL_LOCATION,
        S.LOCATION_TYPE,
        S.PLANNING_LOCATION,
        S.REPORTING_LOCATION,
        S.STATUS,
        S.LOCATION_DISPLAYNAME,
        S.LOCATION_IBP_ASSET_DISPLAYNAME,
        S.LA1,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_locationmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_locationmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_locationmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}