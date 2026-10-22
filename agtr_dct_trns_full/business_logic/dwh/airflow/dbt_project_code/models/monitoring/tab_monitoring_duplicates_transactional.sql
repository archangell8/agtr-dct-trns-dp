-- noqa: disable=all

{% set models = [
    {
        'model_name': 'vw_actual_psi_ibp_stg',
        'key': ['item', 'resourceid', 'location', 'customerid', 'day', 'valuetype'],
        'model_stg': ref('vw_actual_psi_ibp_stg')
    },
    {
        'model_name': 'vw_distribution_ibp_stg',
        'key': ['itemid', 'sourceid', 'finaldestinationid', 'month', 'operation', 'type', 'transmode'],
        'model_stg': ref('vw_distribution_ibp_stg')
    },
    {
        'model_name': 'vw_distribution_operational_stg',
        'key': ['itemid', 'sourceid', 'transmode', 'finaldestinationid', 'day', 'operator', 'operationtype'],
        'model_stg': ref('vw_distribution_operational_stg')
    },
    {
        'model_name': 'vw_onhands_quality_stg',
        'key': ['location', 'item', 'day', 'measure', 'sample_id'],
        'model_stg': ref('vw_onhands_quality_stg')
    },
    {
        'model_name': 'vw_onhands_stg',
        'key': ['item', 'location', 'day', 'company'],
        'model_stg': ref('vw_onhands_stg')
    },
    {
        'model_name': 'tab_resource_capacity_stg',
        'key': ['location', 'resource', 'day', 'classification', 'comments', 'value'],
        'model_stg': ref('tab_resource_capacity_stg')
    },
    {
        'model_name': 'vw_sourcing_contract_details_stg',
        'key': ['id', 'itemid'],
        'model_stg': ref('vw_sourcing_contract_details_stg')
    },
    {
        'model_name': 'vw_transportation_schedule_stg',
        'key': ['date', 'item', 'source', 'destination', 'sourcingcontract', 'carrier', 'type'],
        'model_stg': ref('vw_transportation_schedule_stg')
    },
    {
        'model_name': 'tab_shipment_details_stg',
        'key': ['id', 'itemid'],
        'model_stg': ref('tab_shipment_details_stg')
    },
    {
        'model_name': 'vw_shipment_penalties_stg',
        'key': ['id', 'shipmentid'],
        'model_stg': ref('vw_shipment_penalties_stg')
    },
    {
        'model_name': 'vw_shipment_status_quality_details_stg',
        'key': ['shipmentid', 'status', 'measure'],
        'model_stg': ref('vw_shipment_status_quality_details_stg')
    }
] %}

{{
    config(
        materialized='table'
    )
}}

WITH
{% for model in models %}
    {{ model.model_name }} AS (
        SELECT
            '{{ model.model_name }}' AS MODEL_NAME,
            CONCAT_WS(
                'AND ',
                {% for key in model.key %} -- noqa
                    '{{ key | upper }}= ' || {{ key }}{% if not loop.last %},{% endif %} -- noqa
                {% endfor %}
            ) AS CHAVE,
            QTD_RECORDS
        FROM (
            SELECT
                '{{ model.model_name }}' AS MODEL_NAME,
                COUNT(*) AS QTD_RECORDS,
                {% for key in model.key %}
                    {{key}} {% if not loop.last %},{% endif %}
                {% endfor %}
            FROM {{ model.model_stg }}
            GROUP BY
            {% for key in model.key %}
                {{key}} {% if not loop.last %},{% endif %}
            {% endfor %}
            HAVING COUNT(*) > 1
        )
    ){% if not loop.last %},{% endif %}
{% endfor %}

SELECT
    *,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()) AS TIMESTAMP_EXECUTION
FROM (
    {% for model in models %}
    SELECT * FROM {{model.model_name}}
    {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)
