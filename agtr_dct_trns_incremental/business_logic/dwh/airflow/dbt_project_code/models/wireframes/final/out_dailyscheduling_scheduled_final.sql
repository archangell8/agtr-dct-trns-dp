-- noqa: disable=all
{% set keys = [
    'version_name', 'contract_lineid', 'item', 'supplier_location', 'transmode',
    'source', 'operation_type', 'day', 'location', 'surveyor', 'customer'
    ]
%}

{%
    set another_columns = [
        'scheduledqty'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_dailyscheduling_scheduled', ref('out_dailyscheduling_scheduled'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_dailyscheduling_scheduled') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf38a'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.CONTRACT_LINEID,
        S.ITEM,
        S.SUPPLIER_LOCATION,
        S.TRANSMODE,
        S.SOURCE,
        S.OPERATION_TYPE,
        S.DAY,
        S.LOCATION,
        S.SURVEYOR,
        S.CUSTOMER,
        S.SCHEDULEDQTY,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_dailyscheduling_scheduled', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_dailyscheduling_scheduled') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_dailyscheduling_scheduled') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}