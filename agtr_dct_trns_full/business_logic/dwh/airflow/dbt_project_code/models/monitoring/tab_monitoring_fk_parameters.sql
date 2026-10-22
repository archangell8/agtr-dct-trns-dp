-- noqa: disable=all

{% set models = [
    {
        'model_final': 'uom_conversion',
        'model_stg': ref('vw_uom_conversion_stg'),
        'id_columns': ['ITEM', 'UOMFROM', 'UOMTO'],
        'joins': [
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'ITEM'}],
                'fk_column': 'ITEM_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'distribution_cost',
        'model_stg': ref('vw_distribution_cost_stg'),
        'id_columns': ['BODLANE', 'MONTH', 'ITEM', 'TRANSMODE'],
        'joins': [
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'L2'}],
                'fk_column': 'ITEM_ITEM_FK',
                'parent_model': 'ITEM',
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
                'alias': 'LANE',
                'table': ref('lane'),
                'keys_join': [{'source_column': 'BODLANE', 'target_column': 'LANEID'}],
                'fk_column': 'BODLANE_LANEID_FK',
                'parent_model': 'LANE',
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
                        {% if kj.target_column2  == 'ALL' %}
                            'ALL'
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
