-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
CARRIER AS (
    SELECT DISTINCT
        CARRIER AS CARRIER_DISPLAYNAME,
        TRIM(SPLIT_PART(CARRIER, '-', 1)) AS CARRIER
    FROM {{ ref('shipment_details_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM CARRIER
