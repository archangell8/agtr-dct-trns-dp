-- noqa: disable=all

{% set models = [
    {
        'model_final': 'itemlanetransmode',
        'model_stg': ref('vw_itemlanetransmode_stg'),
        'id_columns': ['BODLANEID', 'TRANSMODE', 'ITEMID'],
        'joins': [
			{
				'alias': 'LAN',
                'table': ref('lane'),
                'keys_join': [{'source_column': 'BODLANEID', 'target_column': 'LANEID'}],
                'parent_model': 'LANE',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'lane',
        'model_stg': ref('vw_lane_stg'),
        'id_columns': ['LANEID'],
        'joins': [
			{
				'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION_FROM', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
				'type': 'left'
            },
			{
				'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION_TO', 'target_column': 'LOCATIONID'}],
                'parent_model': 'LOCATION',
				'type': 'left'
            },
            {
				'alias': 'LOC3',
                'table': 'location',
                'keys_join': [{'source_column': 'LOCATION_FROM_UNIT_STRUCTURE', 'target_column': 'LOCATION_UNIT_STRUCTURE'}],
                'parent_model': 'LOCATION',
				'type': 'distinct'
            },
			{
				'alias': 'LOC4',
                'table': 'location',
                'keys_join': [{'source_column': 'LOCATION_TO_UNIT_STRUCTURE', 'target_column': 'LOCATION_UNIT_STRUCTURE'}],
                'parent_model': 'LOCATION',
				'type': 'distinct'
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
                S.{{ id_column }} {% if not loop.last %}, '-', {% endif %}
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
                SELECT DISTINCT
                    '{{ model.model_final | upper }}' AS ENTITY,
                    PK AS ENTITY_KEY,
                    '{{ kj.source_column }}' AS FIELD_NOT_OK,
                    {{ kj.source_column }} AS VALUE_NOT_OK,
                    {{ kj.source_column }}|| ' DOES NOT EXIST ON {{join.parent_model}}' AS COMMENTS
                FROM FK_{{ model.model_final }}
                WHERE
                    {{ join.alias }}_{{ kj.target_column }} IS NULL
                    AND {{ kj.source_column }} NOT IN ('', 'N/A')
            {% endfor %}
            {% if not loop.last %} UNION ALL {% endif %}
        {% endfor %}
    {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
)
