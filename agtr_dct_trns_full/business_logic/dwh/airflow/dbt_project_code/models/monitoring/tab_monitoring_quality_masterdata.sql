-- noqa: disable=all
{% set models = [
    {
        'model_final': 'vw_location_branchplant_stg',
        'order': '1',
        'model_stg': ref('vw_location_branchplant_stg'),
        'id_columns': ['LOCATIONID'],
        'joins': [
			{
				'alias': 'LA',
                'table': source('pscfl', 'F_MIN_LOCATION_AGRUPADA'),
                'keys_join': [{'source_column': 'LOCATION_UNIT_ID', 'target_column': 'UNIT_ID'}],
                'parent_model': 'F_MIN_LOCATION_AGRUPADA',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'tab_shipment_details_stg',
        'order': '1',
        'model_stg': ref('tab_shipment_details_stg'),
        'id_columns': ['ID'],
        'joins': [
			{
				'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'DESTINATION', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'tab_shipment_details_stg',
        'order': '2',
        'model_stg': ref('tab_shipment_details_stg'),
        'id_columns': ['ID'],
        'joins': [
			{
				'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCE', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'tab_shipment_details_stg',
        'order': '3',
        'model_stg': ref('tab_shipment_details_stg'),
        'id_columns': ['ID'],
        'joins': [
			{
				'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCEBP', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'tab_sourcing_contract_stg',
        'order': '1',
        'model_stg': ref('tab_sourcing_contract_stg'),
        'id_columns': ['ID'],
        'joins': [
			{
				'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCE', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'tab_sourcing_contract_stg',
        'order': '2',
        'model_stg': ref('tab_sourcing_contract_stg'),
        'id_columns': ['ID'],
        'joins': [
			{
				'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'FARM', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'tab_sourcing_contract_stg',
        'order': '3',
        'model_stg': ref('tab_sourcing_contract_stg'),
        'id_columns': ['ID'],
        'joins': [
			{
				'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'DELIVERYUNITID', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
            }
        ],
        'filters':[]
    },
    {
        'model_final': 'itemlanetransmode',
        'order': '1',
        'model_stg': ref('itemlanetransmode'),
        'id_columns': ['BODLANEID', 'TRANSMODE', 'ITEMID'],
        'joins': [],
        'filters':[{'column': 'LEADTIME', 'condition': "> 500"}]
    }
] %}

{{
    config(
        materialized='table',
        cluster_by='ENTITY, FIELD_NOT_OK'
    )
}}

WITH
-- CUSTOM_IBP_ASSET_VALIDATION AS (
--     SELECT
--         'tab_location_internal_stg' AS ENTITY,
--         CONCAT('L.LOCATIONID= ', L.LOCATIONID) AS ENTITY_KEY,
--         'LOCATION_IBP_ASSET' AS FIELD_NOT_OK,
--         L.LOCATION_IBP_ASSET AS VALUE_NOT_OK,
--         CONCAT(
--             'UNIT_ID ', L.LOCATION_UNIT_ID,
--             ' DOES NOT HAVE A VALID LOCATION_IBP_ASSET'
--         ) COMMENTS
--     FROM {{ ref('tab_location_internal_stg') }} AS L
--     WHERE
--         L.LOCATION_UNIT_STRUCTURE NOT IN (
--             'CROP INPUT', 'FARMER FACING', 'FAZENDA EUCALIPTO'
--         )
--         AND L.LOCATION_IBP_ASSET = 'N/A'
--         AND L.LOCATION_NAME NOT LIKE '%FERTILIZANTE%'
--         AND L.LOCATIONID NOT IN (
--             SELECT DISTINCT SOURCE_CODE
--             FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
--             WHERE
--                 CATEGORY = 'LOCATION_MONITORING'
--                 AND STAGE = 'IBP_ASSET'
--         )
--         AND NOT EXISTS (
--             SELECT 1
--             FROM {{ ref('tab_location_internal_stg') }} AS LI
--             WHERE
--                 LI.LOCATION_IBP_ASSET != 'N/A'
--                 AND LI.LOCATION_UNIT_ID = L.LOCATION_UNIT_ID
--         )
-- ),

-- CUSTOM_LANE_OPTIMIZABLE_VALIDATION AS (
--     SELECT DISTINCT
--         'LANE' AS ENTITY,
--         CONCAT('LOCATION_FROM= ', LOCATION_FROM) AS ENTITY_KEY,
--         'ISLANE_OPTIMIZABLE' AS FIELD_NOT_OK,
--         ISLANE_OPTIMIZABLE AS VALUE_NOT_OK,
--         CONCAT(
--             'LOCATION_FROM ', LOCATION_FROM,
--             ' HAS TO RECEIVE VOLUME ON SOURCING CONTRACT'
--         ) AS COMMENTS
--     FROM {{ ref('lane') }} AS LANE_A
--     WHERE
--         LANE_A.ISLANE_OPTIMIZABLE='FALSE'
--         AND LANE_A.LOCATION_FROM IN (
--             SELECT DISTINCT SC.SOURCE
--             FROM {{ ref('sourcing_contract_details') }} AS SC
--             WHERE
--                 1 = 1
--                 AND SC.TORECEIVETOTAL > 0
--         )
--         AND NOT EXISTS (
--             SELECT DISTINCT LANE_B.LOCATION_FROM
--             FROM {{ ref('lane') }} AS LANE_B
--             WHERE
--                 LANE_B.ISLANE_OPTIMIZABLE = 'TRUE'
--                 AND LANE_B.LOCATION_FROM  =LANE_A.LOCATION_FROM
--         )
-- ),
-- Cria um CTE para cada modelo do dicionário
{% for model in models %}
CHECK_{{ model.model_final }}_{{ model.order }} AS (
    SELECT
        '{{ model.model_final | upper }}' AS ENTITY,
        CONCAT(
            {% for id_column in model.id_columns %}
                '{{ id_column }}=', S.{{ id_column }} {% if not loop.last %}, '-', {% endif %}
            {% endfor %}
        ) AS ENTITY_KEY,
        {% if model.joins %}
            {% for join in model.joins %}
                {% for kj in join.keys_join %}
                    '{{ kj.source_column }}' AS FIELD_NOT_OK,
                    {{ kj.source_column }}::STRING AS VALUE_NOT_OK,
                    {{ kj.source_column }}::STRING || ' DOES NOT EXIST ON {{ join.parent_model }}' AS COMMENTS
                {% endfor %}
            {% endfor %}
        {% elif model.filters %}
            {% for filter in model.filters %}
                '{{ filter.column }}' AS FIELD_NOT_OK,
                {{ filter.column }}::STRING AS VALUE_NOT_OK,
                {{ filter.column }}::STRING || ' {{ filter.condition }}' AS COMMENTS
            {% endfor %}
        {% endif %}
    FROM {{ model.model_stg }} AS S
    {% for join in model.joins %}
        LEFT JOIN {{ join.table }} AS {{ join.alias }}
            ON
                {% for kj in join.keys_join %}
                    S.{{ kj.source_column }} = {{ join.alias }}.{{ kj.target_column }}
                    {% if not loop.last %} AND {% endif %}
                {% endfor %}
    {% endfor %}
    WHERE
        1 = 1
        {% for join in model.joins %}
            {% for kj in join.keys_join %}
                AND {{ join.alias }}.{{ kj.target_column }} IS NULL
                AND {{ kj.source_column }} NOT IN ('', 'N/A')
            {% endfor %}
        {% endfor %}
    {% if model.filters %}
        {% for filter in model.filters %}
            AND {{ filter.column }} {{ filter.condition }}
        {% endfor %}
    {% endif %}
)
{% if not loop.last %},{% endif %}
{% endfor %}

SELECT
    ENTITY,
    ENTITY_KEY,
    FIELD_NOT_OK,
    VALUE_NOT_OK,
    COMMENTS,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()) AS TIMESTAMP_EXECUTION
FROM (
    {% for model in models %}
        SELECT DISTINCT
            ENTITY,
            ENTITY_KEY,
            FIELD_NOT_OK,
            VALUE_NOT_OK,
            COMMENTS
        FROM CHECK_{{ model.model_final }}_{{ model.order }}
    {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}

    -- UNION ALL

    -- SELECT DISTINCT
    --     ENTITY,
    --     ENTITY_KEY,
    --     FIELD_NOT_OK,
    --     VALUE_NOT_OK,
    --     COMMENTS
    -- FROM CUSTOM_IBP_ASSET_VALIDATION

    -- UNION ALL

    -- SELECT DISTINCT
    --     ENTITY,
    --     ENTITY_KEY,
    --     FIELD_NOT_OK,
    --     VALUE_NOT_OK,
    --     COMMENTS
    -- FROM CUSTOM_LANE_OPTIMIZABLE_VALIDATION
)

