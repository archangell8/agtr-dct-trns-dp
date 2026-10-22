-- noqa: disable=all

{% set models = [
    {
        'model_name': 'vw_actual_snoe_stg',
        'key': ['itemid', 'sourceid', 'transmode', 'finaldestinationid', 'day', 'operator', 'operationtype'],
        'model_stg': ref('vw_actual_snoe_stg')
    },
    {
        'model_name': 'vw_actual_vessel_load_stg',
        'key': ['date', 'vesselid', 'itemid'],
        'model_stg': ref('vw_actual_vessel_load_stg')
    },
    {
        'model_name': 'vw_distribution_snoe_stg',
        'key': ['referencedate', 'itemid', 'sourceid', 'transmode', 'finaldestinationid', 'day', 'operator', 'operationtype'],
        'model_stg': ref('vw_distribution_snoe_stg')
    },
    {
        'model_name': 'vw_port_down_time_stg',
        'key': ['location', 'startdate'],
        'model_stg': ref('vw_port_down_time_stg')
    },
    {
        'model_name': 'vw_port_penalty_stg',
        'key': ['vesselid', 'date', 'type'],
        'model_stg': ref('vw_port_penalty_stg')
    },
    {
        'model_name': 'vw_port_swap_stg',
        'key': ['creditor', 'debitor', 'location', 'itemid', 'date'],
        'model_stg': ref('vw_port_swap_stg')
    },
    {
        'model_name': 'vw_port_window_stg',
        'key': ['portwindowid'],
        'model_stg': ref('vw_port_window_stg')
    },
    {
        'model_name': 'vw_psi_ibp_stg',
        'key': ['item', 'resourceid', 'location', 'customerid', 'month', 'valuetype'],
        'model_stg': ref('vw_psi_ibp_stg')
    },
    {
        'model_name': 'tab_sales_order_delivery_stg',
        'key': ['demandid'],
        'model_stg': ref('tab_sales_order_delivery_stg')
    },
    {
        'model_name': 'vw_vessel_contract_stg',
        'key': ['location', 'month', 'item', 'type'],
        'model_stg': ref('vw_vessel_contract_stg')
    },
    {
        'model_name': 'tab_vessel_load_baseline_stg',
        'key': ['vesselid', 'itemid', 'referencedate', 'date'],
        'model_stg': ref('tab_vessel_load_baseline_stg')
    },
    {
        'model_name': 'vw_vessel_load_stg',
        'key': ['vesselid', 'itemid', 'date'],
        'model_stg': ref('vw_vessel_load_stg')
    },
    {
        'model_name': 'vw_vessel_details_stg',
        'key': ['id', 'itemid'],
        'model_stg': ref('vw_vessel_details_stg')
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
