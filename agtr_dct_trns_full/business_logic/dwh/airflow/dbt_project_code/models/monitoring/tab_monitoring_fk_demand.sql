-- noqa: disable=all

{% set models = [
    {
        'model_final': 'actual_snoe',
        'model_stg': ref('vw_actual_snoe_stg'),
        'id_columns': ['ITEMID', 'SOURCEID', 'TRANSMODE', 'FINALDESTINATIONID', 'DAY', 'OPERATOR', 'OPERATIONTYPE'],
        'joins': [
			{
                'alias': 'TRANS',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODE', 'target_column': 'TRANSMODE', 'target_column2': 'TRANSMODETYPE'}],
                'fk_column': 'TRANSMODE_TRANSMODE_FK',
                'parent_model': 'TRANSMODE',
				'type': 'distinct2'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'L1'}],
                'fk_column': 'ITEMID_L1_FK',
                'parent_model': 'ITEM',
				'type': 'distinct'
            },
			{
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCEID', 'target_column': 'LOCATION_IBP_ASSET', 'target_column2': 'ALL'}],
                'fk_column': 'SOURCEID_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct2'
            },
			{
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'FINALDESTINATIONID', 'target_column': 'LOCATION_IBP_ASSET', 'target_column2': 'LOCATIONID'}],
                'fk_column': 'FINALDESTINATIONID_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct2'
            }
        ]
    },
    {
        'model_final': 'actual_vessel_load',
        'model_stg': ref('vw_actual_vessel_load_stg'),
        'id_columns': ['DATE', 'VESSELID', 'ITEMID'],
        'joins': [
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            },
			{
                'alias': 'VESS',
                'table': ref('vessel_details'),
                'keys_join': [{'source_column': 'VESSELID', 'target_column': 'ID'}],
                'fk_column': 'VESSELID_ID_FK',
                'parent_model': 'VESSEL',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'distribution_snoe',
        'model_stg': ref('vw_distribution_snoe_stg'),
        'id_columns': ['REFERENCEDATE', 'ITEMID', 'SOURCEID', 'TRANSMODE', 'FINALDESTINATIONID', 'DAY', 'OPERATOR', 'OPERATIONTYPE'],
        'joins': [
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM', 'target_column2': 'L1'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'distinct2'
            },
			{
                'alias': 'TRANS',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODE', 'target_column': 'TRANSMODE', 'target_column2': 'TRANSMODETYPE'}],
                'fk_column': 'TRANSMODE_TRANSMODE_FK',
                'parent_model': 'TRANSMODE',
				'type': 'distinct2'
            },
			{
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCEID', 'target_column': 'LOCATION_IBP_ASSET', 'target_column2': 'ALL'}],
                'fk_column': 'SOURCEID_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct2'
            },
			{
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'FINALDESTINATIONID', 'target_column': 'LOCATION_IBP_ASSET', 'target_column2': 'LOCATIONID'}],
                'fk_column': 'FINALDESTINATIONID_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct2'
            }
        ]
    },
    {
        'model_final': 'port_down_time',
        'model_stg': ref('vw_port_down_time_stg'),
        'id_columns': ['LOCATION', 'STARTDATE'],
        'joins': [
			{
                'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATION_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'port_penalty',
        'model_stg': ref('vw_port_penalty_stg'),
        'id_columns': ['VESSELID', 'DATE', 'TYPE'],
        'joins': [
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            },
			{
                'alias': 'VESS',
                'table': ref('vessel_details'),
                'keys_join': [{'source_column': 'VESSELID', 'target_column': 'ID'}],
                'fk_column': 'VESSELID_ID_FK',
                'parent_model': 'VESSEL',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'port_swap',
        'model_stg': ref('vw_port_swap_stg'),
        'id_columns': ['CREDITOR', 'DEBITOR', 'LOCATION', 'ITEMID', 'DATE'],
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
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'port_window',
        'model_stg': ref('vw_port_window_stg'),
        'id_columns': ['PORTWINDOWID'],
        'joins': [
			{
                'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATION_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'psi_ibp',
        'model_stg': ref('vw_psi_ibp_stg'),
        'id_columns': ['ITEM', 'RESOURCEID', 'LOCATION', 'CUSTOMERID', 'MONTH', 'VALUETYPE'],
        'joins': [
			{
                'alias': 'LOC',
                'table': ref('location'),
                'keys_join': [{'source_column': 'LOCATION', 'target_column': 'LOCATION_IBP_ASSET'}],
                'fk_column': 'LOCATION_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'L1'}],
                'fk_column': 'ITEM_L1_FK',
                'parent_model': 'ITEM',
				'type': 'distinct'
            },
            {
                'alias': 'CUST',
                'table': ref('customer'),
                'keys_join': [{'source_column': 'CUSTOMERID', 'target_column': 'CUSTOMERID', 'target_column2': 'N/A'}],
                'fk_column': 'CUSTOMERID_CUSTOMERID_FK',
                'parent_model': 'CUSTOMER',
				'type': 'distinct2'
            }
        ]
    },
    {
        'model_final': 'sales_order_delivery',
        'model_stg': ref('tab_sales_order_delivery_stg'),
        'id_columns': ['DEMANDID'],
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
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'ITEM'}],
                'fk_column': 'ITEM_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            },
			{
                'alias': 'CUST1',
                'table': ref('customer'),
                'keys_join': [{'source_column': 'CUSTOMERID', 'target_column': 'CUSTOMERID'}],
                'fk_column': 'CUSTOMERID_CUSTOMERID_FK',
                'parent_model': 'CUSTOMER',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'vessel_contract',
        'model_stg': ref('vw_vessel_contract_stg'),
        'id_columns': ['LOCATION', 'MONTH', 'ITEM'],
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
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'ITEM'}],
                'fk_column': 'ITEM_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'vessel_load_baseline',
        'model_stg': ref('tab_vessel_load_baseline_stg'),
        'id_columns': ['VESSELID', 'ITEMID', 'REFERENCEDATE', 'DATE'],
        'joins': [
			{
                'alias': 'VESS',
                'table': ref('vessel_details'),
                'keys_join': [{'source_column': 'VESSELID', 'target_column': 'ID'}],
                'fk_column': 'VESSELID_ID_FK',
                'parent_model': 'VESSEL',
				'type': 'left'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'vessel_load',
        'model_stg': ref('vw_vessel_load_stg'),
        'id_columns': ['VESSELID', 'ITEMID', 'DATE'],
        'joins': [
			{
                'alias': 'VESS',
                'table': ref('vessel_details'),
                'keys_join': [{'source_column': 'VESSELID', 'target_column': 'ID'}],
                'fk_column': 'VESSELID_ID_FK',
                'parent_model': 'VESSEL',
				'type': 'left'
            },
			{
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'vessel_details',
        'model_stg': ref('vw_vessel_details_stg'),
        'id_columns': ['ID', 'ITEMID'],
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
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
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
                        {% elif kj.target_column2  == 'N/A' %}
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
