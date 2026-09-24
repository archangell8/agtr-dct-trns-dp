-- noqa: disable=all
{% set keys = [
    'source'
    ]
%}

{%
    set another_columns = [
        'source_zip', 'source_unit_structure', 'source_group', 'source_country',
        'source_region', 'source_sub_region', 'source_state', 'source_ownership',
        'source_ibp_asset', 'source_code', 'source_operator', 'address',
        'latitude', 'longitude', 'city', 'source_type', 'status',
        'planning_source', 'reporting_source', 'all_source', 'source_displayname',
        'source_label'
   ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_sourcemaster') }}"
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
        S.SOURCE,
        S.SOURCE_ZIP,
        S.SOURCE_UNIT_STRUCTURE,
        S.SOURCE_GROUP,
        S.SOURCE_COUNTRY,
        S.SOURCE_REGION,
        S.SOURCE_SUB_REGION,
        S.SOURCE_STATE,
        S.SOURCE_OWNERSHIP,
        S.SOURCE_IBP_ASSET,
        S.SOURCE_CODE,
        S.SOURCE_OPERATOR,
        S.ADDRESS,
        S.LATITUDE,
        S.LONGITUDE,
        S.CITY,
        S.SOURCE_TYPE,
        S.STATUS,
        S.PLANNING_SOURCE,
        S.REPORTING_SOURCE,
        S.ALL_SOURCE,
        S.SOURCE_DISPLAYNAME,
        S.SOURCE_LABEL,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_sourcemaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_sourcemaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_sourcemaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}