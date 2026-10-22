-- noqa: disable=all
{% set keys = [
    'shipmentid', 'shipmentlineid'
    ]
%}

{%
    set another_columns = [
        'demandid', 'carrier_name', 'profile', 'pallet_type', 'pallet_qty',
        'ctms_load', 'actualshipdate', 'shipment_source', 'shipment_transshipment',
        'shipment_final_destination', 'shipment_ibpasset', 'oc_number', 'tn_rota',
        'oc_emission_date', 'expected_collection_date', 'checkin_date',
        'producer_nf_date', 'cargill_nf_date'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_shipmentmaster') }}"
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
        S.SHIPMENTID,
        S.SHIPMENTLINEID,
        S.DEMANDID,
        S.CARRIER_NAME,
        S.PROFILE,
        S.PALLET_TYPE,
        S.PALLET_QTY,
        S.CTMS_LOAD,
        S.ACTUALSHIPDATE,
        S.SHIPMENT_SOURCE,
        S.SHIPMENT_TRANSSHIPMENT,
        S.SHIPMENT_FINAL_DESTINATION,
        S.SHIPMENT_IBPASSET,
        S.OC_NUMBER,
        S.TN_ROTA,
        S.OC_EMISSION_DATE,--#
        S.EXPECTED_COLLECTION_DATE,
        S.CHECKIN_DATE,
        S.PRODUCER_NF_DATE,
        S.CARGILL_NF_DATE,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_shipmentmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_shipmentmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_shipmentmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}
