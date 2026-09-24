-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
TRANSSHIPMENT AS (
    SELECT DISTINCT LOCATIONID AS TRANSSHIPMENT
    FROM {{ ref('location_master') }}
    WHERE
        LOCATION_UNIT_STRUCTURE IN ('TRANSBORDO','PORTO FLUVIAL')
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM TRANSSHIPMENT
