-- noqa: disable=all

{% set models = [

        {
            'model_final': ref('uom_conversion'),
            'model_name': 'uom_conversion'
        },
        {
            'model_final': ref('currency_conversion'),
            'model_name': 'currency_conversion'
        },
        {
            'model_final': ref('distribution_cost'),
            'model_name': 'distribution_cost'
        },
        {
            'model_final': ref('customer'),
            'model_name': 'customer'
        },
        {
            'model_final': ref('item'),
            'model_name': 'item'
        },
        {
            'model_final': ref('itemlanetransmode'),
            'model_name': 'itemlanetransmode'
        },
        {
            'model_final': ref('lane'),
            'model_name': 'lane'
        },
        {
            'model_final': ref('location'),
            'model_name': 'location'
        },
        {
            'model_final': ref('location_bp'),
            'model_name': 'location_bp'
        },
        {
            'model_final': ref('supplier'),
            'model_name': 'supplier'
        },
        {
            'model_final': ref('transmode'),
            'model_name': 'transmode'
        },
        {
            'model_final': ref('loading_capacity'),
            'model_name': 'loading_capacity'
        },
        {
            'model_final': ref('location_storage_capacity'),
            'model_name': 'location_storage_capacity'
        },
        {
            'model_final': ref('transportation_contract_details'),
            'model_name': 'transportation_contract_details'
        },
        {
            'model_final': ref('unloading_capacity'),
            'model_name': 'unloading_capacity'
        },
        {
            'model_final': ref('actual_snoe'),
            'model_name': 'actual_snoe'
        },
        {
            'model_final': ref('actual_vessel_load'),
            'model_name': 'actual_vessel_load'
        },
        {
            'model_final': ref('distribution_snoe'),
            'model_name': 'distribution_snoe'
        },
        {
            'model_final': ref('port_down_time'),
            'model_name': 'port_down_time'
        },
        {
            'model_final': ref('port_penalty'),
            'model_name': 'port_penalty'
        },
        {
            'model_final': ref('port_swap'),
            'model_name': 'port_swap'
        },
        {
            'model_final': ref('port_window'),
            'model_name': 'port_window'
        },
        {
            'model_final': ref('psi_ibp'),
            'model_name': 'psi_ibp'
        },
        {
            'model_final': ref('sales_order_delivery'),
            'model_name': 'sales_order_delivery'
        },
        {
            'model_final': ref('vessel_contract'),
            'model_name': 'vessel_contract'
        },
        {
            'model_final': ref('vessel_load_baseline'),
            'model_name': 'vessel_load_baseline'
        },
        {
            'model_final': ref('vessel_load'),
            'model_name': 'vessel_load'
        },
        {
            'model_final': ref('vessel_details'),
            'model_name': 'vessel_details'
        },
        {
            'model_final': ref('actual_psi_ibp'),
            'model_name': 'actual_psi_ibp'
        },
        {
            'model_final': ref('distribution_ibp'),
            'model_name': 'distribution_ibp'
        },
        {
            'model_final': ref('distribution_operational'),
            'model_name': 'distribution_operational'
        },
        {
            'model_final': ref('onhands_quality'),
            'model_name': 'onhands_quality'
        },
        {
            'model_final': ref('onhands'),
            'model_name': 'onhands'
        },
        {
            'model_final': ref('resource_capacity'),
            'model_name': 'resource_capacity'
        },
        {
            'model_final': ref('shipment_details'),
            'model_name': 'shipment_details'
        },
        {
            'model_final': ref('shipment_penalties'),
            'model_name': 'shipment_penalties'
        },
        {
            'model_final': ref('shipment_status_quality_details'),
            'model_name': 'shipment_status_quality'
        },
        {
            'model_final': ref('sourcing_contract_details'),
            'model_name': 'sourcing_contract_details'
        },
        {
            'model_final': ref('transportation_schedule'),
            'model_name': 'transportation_schedule'
        }

] %}
{{
    config(
        materialized='table'
    )
}}
WITH
-- Cria um CTE para cada modelo do dicionário
{% for model in models %}
FK_{{ model.model_name }} AS (
    SELECT
        '{{model.model_name | upper}}' AS MODEL,
        COUNT(*) AS QTD_RECORDS,
        CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()) AS TIMESTAMP_EXECUTION
    FROM {{ model.model_final }}
){% if not loop.last %},{% endif %}
{% endfor %}
{% for model in models %}
SELECT * FROM FK_{{ model.model_name }}
{% if not loop.last %}UNION{% endif %}
{% endfor %}