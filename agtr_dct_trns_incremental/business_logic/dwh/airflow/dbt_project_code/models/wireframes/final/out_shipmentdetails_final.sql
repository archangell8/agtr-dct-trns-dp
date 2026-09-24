-- noqa: disable=all
{% set keys = [
    'version_name', 'shipment_lineid', 'source', 'location', 'item', 'bodlane',
    'contract_lineid', 'transmode', 'carrier', 'vehicleid', 'surveyor',
    'operation_type', 'day'
    ]
%}

{%
    set another_columns = [
    'estimated_ship_date', 'actual_ship_date', 'shipment_scheduled_date',
    'shipment_arrival_date', 'estimated_delivery_date', 'actual_delivery_date',
    'load_application_date', 'planned_cost', 'actual_cost', 'shipmentquantity',
    'shipment_details_status', 'shipment_sales_order',
    'shipment_final_destination', 'invoice_qty', 'unloaded_qty',
    'unloaded_vs_invoice'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_shipmentdetails', ref('out_shipmentdetails'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_shipmentdetails') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf16c'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.SHIPMENT_LINEID,
        S.SOURCE,
        S.LOCATION,
        S.ITEM,
        S.BODLANE,
        S.CONTRACT_LINEID,
        S.TRANSMODE,
        S.CARRIER,
        S.VEHICLEID,
        S.SURVEYOR,
        S.OPERATION_TYPE,
        S.DAY,
        S.ESTIMATED_SHIP_DATE,
        S.ACTUAL_SHIP_DATE,
        S.SHIPMENT_SCHEDULED_DATE,
        S.SHIPMENT_ARRIVAL_DATE,
        S.ESTIMATED_DELIVERY_DATE,
        S.ACTUAL_DELIVERY_DATE,
        S.LOAD_APPLICATION_DATE,
        S.PLANNED_COST,
        S.ACTUAL_COST,
        S.SHIPMENTQUANTITY,
        S.INVOICE_QTY,
        S.UNLOADED_QTY,
        S.UNLOADED_VS_INVOICE,
        S.SHIPMENT_DETAILS_STATUS,
        S.SHIPMENT_SALES_ORDER,
        S.SHIPMENT_FINAL_DESTINATION,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_shipmentdetails', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_shipmentdetails') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_shipmentdetails') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}