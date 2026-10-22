-- noqa: disable=all

{% set models = [
    {
        'model_final': 'sourcing_contract_details',
        'model_stg': ref('vw_sourcing_contract_details_stg'),
        'id_columns': ['ID', 'ITEMID'],
        'joins': [
                        {
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCE', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATION_SOURCE_FK',
                'parent_model': 'LOCATION',
                'type': 'left'
            },
            {
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'DELIVERYUNITID', 'target_column': 'LOCATIONID'}],
                'fk_column': 'LOCATION_DELIVERYUNITID_FK',
                'parent_model': 'LOCATION',
                'type': 'left'
            },
            {
                'alias': 'SUP',
                'table': ref('supplier'),
                'keys_join': [{'source_column': 'SUPPLIERID', 'target_column': 'SUPPLIERID'}],
                'fk_column': 'SUPPLIER_SUPPLIERID_FK',
                'parent_model': 'SUPPLIER',
                'type': 'left'
            },
            {
                'alias': 'TRANS',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODE', 'target_column': 'TRANSMODE'}],
                'fk_column': 'TRANSMODE_TRANSMODE_FK',
                'parent_model': 'TRANSMODE',
                'type': 'left'
            },
            {
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM'}],
                'fk_column': 'ITEM_ITEMID_FK',
                'parent_model': 'ITEM',
                'type': 'left'
            }
        ]
    },
    {
        'model_final': 'actual_psi_ibp',
        'model_stg': ref('vw_actual_psi_ibp_stg'),
        'id_columns': ['ITEM', 'RESOURCEID', 'LOCATION', 'CUSTOMERID', 'DAY', 'VALUETYPE'],
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
        'model_final': 'distribution_ibp',
        'model_stg': ref('vw_distribution_ibp_stg'),
        'id_columns': ['ITEMID', 'SOURCEID', 'FINALDESTINATIONID', 'MONTH', 'OPERATION', 'TYPE', 'TRANSMODE'],
        'joins': [
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
                'keys_join': [{'source_column': 'SOURCEID', 'target_column': 'LOCATION_IBP_ASSET'}],
                'fk_column': 'SOURCEID_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct'
            },
			{
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'FINALDESTINATIONID', 'target_column': 'LOCATION_IBP_ASSET'}],
                'fk_column': 'FINALDESTINATIONID_LOCATION_IBP_ASSET_FK',
                'parent_model': 'LOCATION',
				'type': 'distinct'
            },
			{
                'alias': 'TRANS',
                'table': ref('transmode'),
                'keys_join': [{'source_column': 'TRANSMODE', 'target_column': 'TRANSMODE'}],
                'fk_column': 'TRANSMODE_TRANSMODE_FK',
                'parent_model': 'TRANSMODE',
				'type': 'distinct'
            }
        ]
    },
    {
        'model_final': 'distribution_operational',
        'model_stg': ref('vw_distribution_operational_stg'),
        'id_columns': ['ITEMID', 'SOURCEID', 'TRANSMODE', 'FINALDESTINATIONID', 'DAY', 'OPERATOR', 'OPERATIONTYPE'],
        'joins': [
			{
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCEID', 'target_column': 'LOCATION_IBP_ASSET', 'target_column2': 'ALL'}],
                'fk_column': 'SOURCE_LOCATION_IBP_ASSET_FK',
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
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEMID', 'target_column': 'ITEM', 'target_column2': 'L1'}],
                'fk_column': 'ITEMID_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'distinct2'
            }
        ]
    },
    {
        'model_final': 'onhands_quality',
        'model_stg': ref('vw_onhands_quality_stg'),
        'id_columns': ['LOCATION', 'ITEM', 'DAY', 'MEASURE'],
        'joins': [
            {
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'ITEM'}],
                'fk_column': 'ITEM_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
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
    },
    {
        'model_final': 'onhands',
        'model_stg': ref('vw_onhands_stg'),
        'id_columns': ['ITEM', 'LOCATION', 'DAY', 'COMPANY'],
        'joins': [
            {
                'alias': 'ITM',
                'table': ref('item'),
                'keys_join': [{'source_column': 'ITEM', 'target_column': 'ITEM'}],
                'fk_column': 'ITEM_ITEM_FK',
                'parent_model': 'ITEM',
				'type': 'left'
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
    },
    {
        'model_final': 'resource_capacity',
        'model_stg': ref('tab_resource_capacity_stg'),
        'id_columns': ['LOCATION', 'RESOURCE', 'DAY', 'CLASSIFICATION', 'COMMENTS', 'VALUE'],
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
        'model_final': 'shipment_details',
        'model_stg': ref('tab_shipment_details_stg'),
        'id_columns': ['ID', 'ITEMID'] ,
        'joins': [
			{
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCE', 'target_column': 'LOCATIONID'}],
                'fk_column': 'SOURCE_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            },
			{
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCEBP', 'target_column': 'LOCATIONID'}],
                'fk_column': 'SOURCEBP_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            },
            {
                'alias': 'LOC3',
                'table': ref('location'),
                'keys_join': [{'source_column': 'DESTINATION', 'target_column': 'LOCATIONID'}],
                'fk_column': 'DESTINATION_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            },
			{
                'alias': 'L',
                'table': ref('lane'),
                'keys_join': [{'source_column': 'LANEID', 'target_column': 'LANEID'}],
                'fk_column': 'LANEID_LANEID_FK',
                'parent_model': 'LANE',
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
        'model_final': 'shipment_penalties',
        'model_stg': ref('vw_shipment_penalties_stg'),
        'id_columns': ['ID', 'SHIPMENTID'],
        'joins': [
			{
                'alias': 'SHIP',
                'table': ref('shipment_details'),
                'keys_join': [{'source_column': 'SHIPMENTID', 'target_column': 'ID'}],
                'fk_column': 'SHIPMENTID_ID_FK',
                'parent_model': 'SHIPMENT',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'shipment_status_quality_details',
        'model_stg': ref('vw_shipment_status_quality_details_stg'),
        'id_columns': ['SHIPMENTID', 'STATUS', 'MEASURE'] ,
        'joins': [
			{
                'alias': 'SHIP',
                'table': ref('shipment_details'),
                'keys_join': [{'source_column': 'SHIPMENTID', 'target_column': 'ID'}],
                'fk_column': 'SHIPMENTID_ID_FK',
                'parent_model': 'SHIPMENT',
				'type': 'left'
            }
        ]
    },
    {
        'model_final': 'transportation_schedule',
        'model_stg': ref('vw_transportation_schedule_stg'),
        'id_columns': ['DATE', 'ITEM', 'SOURCE', 'DESTINATION', 'SOURCINGCONTRACT', 'CARRIER', 'TYPE'],
        'joins': [
			{
                'alias': 'LOC1',
                'table': ref('location'),
                'keys_join': [{'source_column': 'SOURCE', 'target_column': 'LOCATIONID'}],
                'fk_column': 'SOURCE_LOCATIONID_FK',
                'parent_model': 'LOCATION',
				'type': 'left'
            },
			{
                'alias': 'LOC2',
                'table': ref('location'),
                'keys_join': [{'source_column': 'DESTINATION', 'target_column': 'LOCATIONID'}],
                'fk_column': 'DESTINATION_LOCATIONID_FK',
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
