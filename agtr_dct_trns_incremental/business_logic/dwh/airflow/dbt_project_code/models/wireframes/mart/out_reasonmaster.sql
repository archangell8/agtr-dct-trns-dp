-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
REASON AS (
    SELECT DISTINCT
        TYPE_OF_COST,
        REASON
    FROM {{ ref('shipment_penalties_master') }}

    UNION ALL

    SELECT
        'N/A' AS TYPE_OF_COST,
        'ALL1' AS REASON
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM REASON
