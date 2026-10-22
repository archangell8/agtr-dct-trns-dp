-- noqa: disable=all
-- Define keys for models
{% set models = {
    'vw_currency_conversion_stg': ['currencyfrom', 'currencyto', 'conversionstart', 'conversionend'],
    'vw_uom_conversion_stg': ['item', 'uomfrom', 'uomto'],
    'vw_distribution_cost_stg':['item', 'transmode', 'bodlane', 'month']
} %}

-- Explicit dependency declarations for Cosmos
{%
    set model_refs = {
        'vw_currency_conversion_stg': ref('vw_currency_conversion_stg'),
        'vw_uom_conversion_stg': ref('vw_uom_conversion_stg'),
        'vw_distribution_cost_stg': ref('vw_distribution_cost_stg')
    }
%}

{{
    config(
        materialized='table'
    )
}}

-- -- Emit dependencies for Cosmos parsing
-- {% for ref_name in model_refs.values() %}
--     {{ ref_name }}
-- {% endfor %}

WITH
{% for model_name, keys in models.items() %}
    {{ model_name }} AS (
        SELECT
            '{{ model_name }}' AS MODEL_NAME,
            CONCAT_WS(
                'AND ',
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
