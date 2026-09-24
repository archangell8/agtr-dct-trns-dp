-- noqa: disable=all
{% set keys = [
    'bodlane'
    ]
%}

{%
    set another_columns = [
        'lane_description', 'from_location', 'to_location', 'destination',
        'origin', 'origin_sub_region', 'optimizable'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_lanemaster') }}"
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
        S.BODLANE,
        S.LANE_DESCRIPTION,
        S.FROM_LOCATION,
        S.TO_LOCATION,
        S.DESTINATION,
        S.ORIGIN,
        S.ORIGIN_SUB_REGION,
        S.OPTIMIZABLE,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_lanemaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_lanemaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_lanemaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}