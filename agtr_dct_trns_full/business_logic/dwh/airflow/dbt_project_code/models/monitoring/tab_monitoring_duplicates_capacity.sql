-- noqa: disable=all
-- Define keys for models
{% set models = {
    'vw_loading_capacity_stg': ['itemid', 'startdate', 'enddate', 'transmodetype', 'location'],
    'vw_location_storage_capacity_stg': ['itemid', 'locationid', 'month'],
    'tab_transportation_contract_details_stg': ['transportationcontractid', 'transportationcontractlineid', 'startdate', 'enddate'],
    'vw_unloading_capacity_stg': ['transmodetype', 'itemid', 'location', 'startdate', 'enddate'],
} %}

-- Explicit dependency declarations for Cosmos
{%
    set model_refs = {
        'vw_loading_capacity_stg': ref('vw_loading_capacity_stg'),
        'vw_location_storage_capacity_stg': ref('vw_location_storage_capacity_stg'),
        'tab_transportation_contract_details_stg': ref('tab_transportation_contract_details_stg'),
        'vw_unloading_capacity_stg': ref('vw_unloading_capacity_stg')
    }
%}

{{
    config(
        materialized='table'
    )
}}

WITH
{% for model_name, keys in models.items() %}
    {{ model_name }} AS (
        SELECT
            '{{ model_name }}' AS MODEL_NAME,
            CONCAT_WS(
                ' AND ',
                {% for key in keys %}
                    '{{ key | upper }}= ' || {{ key }}{% if not loop.last %},{% endif %}
                {% endfor %}
            ) AS CHAVE,
            QTD_RECORDS
        FROM (
            SELECT
                '{{ model_name }}' AS MODEL_NAME,
                COUNT(*) AS QTD_RECORDS,
                {{ keys | join(', ') }}
            FROM {{ model_refs[model_name] }}
            GROUP BY {{ keys | join(', ') }}
            HAVING COUNT(*) > 1
        )
    ){% if not loop.last %},{% endif %}
{% endfor %}

SELECT
    *,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()) AS TIMESTAMP_EXECUTION
FROM (
    {% for model_name in models.keys() %}
        SELECT * FROM {{ model_name }}
        {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)
