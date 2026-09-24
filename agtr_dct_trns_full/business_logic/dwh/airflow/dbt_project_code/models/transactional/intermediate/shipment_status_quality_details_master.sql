-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'status', 'shipmentid', 'measure'
] %}
{% set list_another_columns = [
    'statusreferencedate', 'bk', 'uom', 'quantity',
    'value', 'unit', 'statusqualityreferencedate'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
SHIPMENT_STATUS_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_shipment_status_quality_details_stg') }}
    QUALIFY RN = 1
),

SHIPMENT_STATUS AS (
    SELECT
    	SHIPMENT_STG.SHIPMENTID,
        SHIPMENT_STG.STATUS,
        SHIPMENT_STG.STATUSREFERENCEDATE,
        SHIPMENT_STG.QUANTITY,
        SHIPMENT_STG.STATUSQUALITYREFERENCEDATE,
        SHIPMENT_STG.MEASURE,
        SHIPMENT_STG.VALUE,
        SHIPMENT_STG.UNIT,
        SHIPMENT_STG.BK,
        SHIPMENT_STG.UOM,
        SHIPMENT_STG.HASH_ID
    FROM SHIPMENT_STATUS_STG AS SHIPMENT_STG
    INNER JOIN {{ ref('shipment_details_master') }} AS SHIP
        ON SHIPMENT_STG.SHIPMENTID = SHIP.ID
)

SELECT *
FROM SHIPMENT_STATUS
