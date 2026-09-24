-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
VEHICLE_MASTER AS (
    SELECT DISTINCT COALESCE(VEHICLEID, 'N/A') AS VEHICLEID
    FROM {{ ref('shipment_details_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM VEHICLE_MASTER
