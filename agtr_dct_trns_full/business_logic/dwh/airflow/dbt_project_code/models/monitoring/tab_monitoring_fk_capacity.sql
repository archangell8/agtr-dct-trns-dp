-- noqa: disable=all

{% set models = [
    {
        'model_final': 'loading_capacity',
        'model_stg': ref('vw_loading_capacity_stg'),
        'id_columns': ['ITEMID', 'STARTDATE', 'ENDDATE', 'TRANSMODETYPE', 'LOCATION'],
        'joins': [
			{
                'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATION_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'L2'}],
                'fk_column': 'ITEMID_L2_FK',
                'parent_model': 'ITEM',
				'type': 'distinct'
            },
			{
                'alias': 'TRANS',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODETYPE', 'target_column': 'TRANSMODETYPE'}],
                'fk_column': 'TRANSMODETYPE_TRANSMODETYPE_FK',
                'parent_model': 'TRANSMODE',
				'type': 'distinct'
            }

        ]
    },
    {
        'model_final': 'location_storage_capacity',
        'model_stg': ref('vw_location_storage_capacity_stg'),
        'id_columns': ['ITEMID', 'LOCATIONID', 'MONTH'],
        'joins': [
			{
                'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATIONID', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATIONID_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'L2'}],
                'fk_column': 'ITEMID_L2_FK',
                'parent_model': 'ITEM',
				'type': 'distinct'
            }
        ]
    },
    {
        'model_final': 'transportation_contract_details',
        'model_stg': ref('tab_transportation_contract_details_stg'),
        'id_columns': ['TRANSPORTATIONCONTRACTID', 'TRANSPORTATIONCONTRACTLINEID'],
        'joins': [
			{
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCE', 'target_column': 'LOCATIONID', 'target_column2': 'N/A'}],
                'fk_column': 'SOURCE_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct2'
            },
			{
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'DESTINATION', 'target_column': 'LOCATION_CODE'}],
                'fk_column': 'DESTINATION_LOCATIONCODE_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct'
            },
			{
                'alias': 'TRA',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODE', 'target_column': 'TRANSMODE'}],
                'fk_column': 'TRANSMODE_TRANSMODE_FK',
                'parent_model': 'TRANSMODE',
				'type': 'left'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'L1'}],
                'fk_column': 'ITEMID_L1_FK',
                'parent_model': 'ITEM',
				'type': 'distinct'
            }
        ]
    },
    {
        'model_final': 'unloading_capacity',
        'model_stg': ref('vw_unloading_capacity_stg'),
        'id_columns': ['TRANSMODETYPE', 'ITEMID', 'LOCATION', 'STARTDATE', 'ENDDATE'],
        'joins': [
			{
                'alias': 'TRANS',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODETYPE', 'target_column': 'TRANSMODETYPE'}],
                'fk_column': 'TRANSMODETYPE_TRANSMODETYPE_FK',
                'parent_model': 'TRANSMODE',
				'type': 'distinct'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEMSTAGE'}],
                'fk_column': 'ITEMID_ITEMSTAGE_FK',
                'parent_model': 'ITEM',
				'type': 'distinct'
            },
			{
                'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATION_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            }
        ]
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
FK_{{ model.model_final }} AS (
    SELECT
        -- Concatena as chaves da tabela, caso haja mais de uma
        CONCAT(
            {% for id_column in model.id_columns %}
                '{{ id_column }}=', S.{{ id_column }} {% if not loop.last %}, '-', {% endif %}
            {% endfor %}
        ) AS PK,
        {% for join in model.joins %}
            {% for kj in join.keys_join %}
                '{{ kj.source_column }} / {{ kj.target_column }}=' || S.{{ kj.source_column }} AS {{ model.model_final }}_{{ kj.source_column }}_FK,
                {{ join.alias }}.{{ kj.target_column }} AS {{ join.alias }}_{{ kj.target_column }},
                '{{ join.parent_model | upper }}' AS {{ model.model_final }}_{{ kj.source_column }}_TARGET_MODEL,
            {% endfor %}
        {% endfor %}
        S.*
    FROM {{ model.model_stg }} AS S
    {% for join in model.joins %}
    {% if join.type == 'left' %}
        LEFT JOIN {{ join.table }} AS {{ join.alias }}
            ON
                {% for kj in join.keys_join %}
                    S.{{ kj.source_column }} = {{ join.alias }}.{{ kj.target_column }}
                    {% if not loop.last %} AND {% endif %}
                {% endfor %}
    {% else %}
        LEFT JOIN (
            {% for kj in join.keys_join %}
            SELECT DISTINCT {{ kj.target_column }} FROM {{ join.table }}
            {% if join.type == 'distinct2' %}
                UNION
                SELECT DISTINCT
                        {% if kj.target_column2  == 'N/A' %}
                            'N/A'
                        {% else %}
                            {{ kj.target_column2 }}
                        {% endif %}
                    AS {{ kj.target_column }}
                FROM {{ join.table }}
            {% endif %}
            {% endfor %}
        ) AS {{ join.alias }}
             ON
                {% for kj in join.keys_join %}
                    S.{{ kj.source_column }} = {{ join.alias }}.{{ kj.target_column }}
                    {% if not loop.last %} AND {% endif %}
                {% endfor %}
    {% endif %}
    {% endfor %}
    WHERE 1 = 1
)
{% if not loop.last %},{% endif %}
{% endfor %}

SELECT
    *,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()) AS TIMESTAMP_EXECUTION
FROM (
    {% for model in models %}
        {% for join in model.joins %}
            {% for kj in join.keys_join %}
                SELECT
                    '{{ model.model_final | upper }}' AS MODEL_NAME,
                    PK,
                    {{ model.model_final }}_{{ kj.source_column }}_TARGET_MODEL AS TARGET_MODEL,
                    {{ model.model_final }}_{{ kj.source_column }}_FK AS MISSING_FK
                FROM FK_{{ model.model_final }}
                WHERE {{ join.alias }}_{{ kj.target_column }} IS NULL
            {% endfor %}
            {% if not loop.last %} UNION ALL {% endif %}
        {% endfor %}
    {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)
