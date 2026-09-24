-- noqa: disable=all
{% set keys = [
    'resource'
    ]
%}

{%
    set another_columns = [
        'resource_alternate_group2',
        'resource_type',
        'resource_alternate_group1',
        'resource_all'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_resourcemaster') }}"
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
        S.RESOURCE_ALTERNATE_GROUP2,
        S.RESOURCE_TYPE,
        S.RESOURCE,
        S.RESOURCE_ALTERNATE_GROUP1,
        S.RESOURCE_ALL,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_resourcemaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_resourcemaster') }} AS S
    /* If incremental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_resourcemaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}
