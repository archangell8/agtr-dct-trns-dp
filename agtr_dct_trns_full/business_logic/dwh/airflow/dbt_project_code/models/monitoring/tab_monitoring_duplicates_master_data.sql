-- noqa: disable=all
-- Define keys for models
{%
    set models = {
        'tab_customer_stg': ['customerid'],
        'vw_item_stg': ['item'],
        'vw_itemlanetransmode_stg': ['bodlaneid', 'transmode', 'itemid'],
        'tab_location_stg': ['locationid'],
        'vw_supplier_stg': ['supplierid'],
        'vw_lane_stg': ['laneid'],
        'vw_transmode_stg': ['transmode'],
        'vw_location_bp_stg': ['bp_number']
    }
%}

-- Explicit dependency declarations for Cosmos
{%
    set model_refs = {
        'tab_customer_stg': ref('tab_customer_stg'),
        'vw_item_stg': ref('vw_item_stg'),
        'vw_itemlanetransmode_stg': ref('vw_itemlanetransmode_stg'),
        'tab_location_stg': ref('tab_location_stg'),
        'vw_supplier_stg': ref('vw_supplier_stg'),
        'vw_lane_stg': ref('vw_lane_stg'),
        'vw_transmode_stg': ref('vw_transmode_stg'),
        'vw_location_bp_stg': ref('vw_location_bp_stg')
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
                    '{{ key | upper }}= ' || IFNULL({{ key }}, 'NULL'){% if not loop.last %},{% endif %}
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
