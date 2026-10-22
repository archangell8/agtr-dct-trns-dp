-- noqa: disable=all
{% set keys = [
    'version_name',
    'shipment_lineid',
    'vehicle',
    'transshipment',
    'source',
    'supplierid',
    'item',
    'transmode',
    'location',
    'carrier',
    'customer',
    'operation_type'
    ]
%}

{%
    set another_columns = [
        'volume'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_shipment_loadtracking_details', ref('out_shipment_loadtracking_details'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_shipment_loadtracking_details') }}"
] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf06'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.SHIPMENT_LINEID,
        S.VEHICLE,
        S.TRANSSHIPMENT,
        S.SOURCE,
        S.SUPPLIERID,
        S.ITEM,
        S.TRANSMODE,
        S."LOCATION",
        S.CARRIER,
        S.CUSTOMER,
        S.OPERATION_TYPE,
        S.VOLUME,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_shipment_loadtracking_details', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_shipment_loadtracking_details') }} AS S
    /* If incremental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_shipment_loadtracking_details') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}
