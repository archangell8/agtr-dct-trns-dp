-- noqa: disable=all
{% set keys = [
    'version_name', 'location', 'item', 'day', 'quality', 'sample_id'
    ]
%}

{%
    set another_columns = [
    'oh_quality_details', 'oh_quality_no_unit'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_onhandsqualitydetails', ref('out_onhandsqualitydetails'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_onhandsqualitydetails') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf41b'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.LOCATION,
        S.ITEM,
        S.DAY,
        S.QUALITY,
        S.SAMPLE_ID,
        S.OH_QUALITY_DETAILS,
        S.OH_QUALITY_NO_UNIT,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_onhandsqualitydetails', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_onhandsqualitydetails') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_onhandsqualitydetails') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}