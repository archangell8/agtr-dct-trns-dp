-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'shipmentid'
] %}
{% set list_another_columns = [
    'driver', 'penaltycost', 'currency', 'referencedate', 'type_of_cost',
    'reason', 'sub_reason'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
SHIPMENT_PENALTIES_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_shipment_penalties_stg') }}
    QUALIFY RN = 1
),

SHIPMENT_PENALTIES AS (
    SELECT
        SHIPMENT_STG.ID,
        SHIPMENT_STG.SHIPMENTID,
        SHIPMENT_STG.DRIVER,
        SHIPMENT_STG.PENALTYCOST,
        SHIPMENT_STG.CURRENCY,
        SHIPMENT_STG.REFERENCEDATE,
        SHIPMENT_STG.TYPE_OF_COST,
        SHIPMENT_STG.REASON,
        SHIPMENT_STG.SUB_REASON,
        SHIPMENT_STG.HASH_ID
    FROM SHIPMENT_PENALTIES_STG AS SHIPMENT_STG
    INNER JOIN {{ ref('shipment_details_master') }} AS SHIP
        ON TRY_CAST(SHIP.ID AS BIGINT) = TRY_CAST(SHIPMENT_STG.SHIPMENTID AS BIGINT)
)

SELECT *
FROM SHIPMENT_PENALTIES
