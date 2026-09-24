-- noqa: disable=all

{% set models = {
    'customer': ref('customer'),
    'item': ref('item'),
    'lane': ref('lane'),
    'itemlanetransmode': ref('itemlanetransmode'),
    'location': ref('location'),
    'transmode': ref('transmode'),
    'supplier': ref('supplier'),
    'location_bp': ref('location_bp'),
    'currency_conversion': ref('currency_conversion'),
    'uom_conversion': ref('uom_conversion'),
    'distribution_cost': ref('distribution_cost'),
    'loading_capacity': ref('loading_capacity'),
    'location_storage_capacity': ref('location_storage_capacity'),
    'transportation_contract_details': ref('transportation_contract_details'),
    'unloading_capacity': ref('unloading_capacity'),
    'actual_snoe': ref('actual_snoe'),
    'actual_vessel_load': ref('actual_vessel_load'),
    'distribution_snoe': ref('distribution_snoe'),
    'port_down_time': ref('port_down_time'),
    'port_penalty': ref('port_penalty'),
    'port_swap': ref('port_swap'),
    'port_window': ref('port_window'),
    'psi_ibp': ref('psi_ibp'),
    'sales_order_delivery': ref('sales_order_delivery'),
    'vessel_contract': ref('vessel_contract'),
    'vessel_details': ref('vessel_details'),
    'vessel_load_baseline': ref('vessel_load_baseline'),
    'vessel_load': ref('vessel_load'),
    'actual_psi_ibp': ref('actual_psi_ibp'),
    'distribution_ibp': ref('distribution_ibp'),
    'distribution_operational': ref('distribution_operational'),
    'onhands': ref('onhands'),
    'onhands_quality': ref('onhands_quality'),
    'shipment_details': ref('shipment_details'),
    'shipment_status_quality_details': ref('shipment_status_quality_details'),
    'shipment_penalties': ref('shipment_penalties'),
    'sourcing_contract_details': ref('sourcing_contract_details'),
    'transportation_schedule': ref('transportation_schedule'),
    'resource_capacity': ref('resource_capacity')
} %}

{{
    config(
        materialized='table'
    )
}}

SELECT
    MODEL_NAME,
    CDP_TIMESTAMP
FROM (
    {% for model_name in models.keys() %}
        SELECT
            UPPER('{{ model_name }}') AS MODEL_NAME,
            TO_CHAR(CONVERT_TIMEZONE(
                'UTC', CURRENT_TIMESTAMP()), 'YYYY-MM-DD HH24:MI:SS'
            ) AS CDP_TIMESTAMP,
            MAX(CDP_TIMESTAMP_INC)
        FROM {{ models[model_name] }}
        {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)