-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
DEMAND_TYPE AS (
    SELECT DEMAND_TYPE
    FROM (
        VALUES
        ('VesselDemand'),
        ('SalesOrderDelivery'),
        ('InventoryDemand'),
        ('CrushingPlant'),
        ('AmidosDemand')
    ) AS V (DEMAND_TYPE)
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM DEMAND_TYPE
