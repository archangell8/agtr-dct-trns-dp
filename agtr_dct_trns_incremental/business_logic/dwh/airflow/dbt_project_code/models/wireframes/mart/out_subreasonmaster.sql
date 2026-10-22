-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
SUBREASON AS (
    SELECT DISTINCT SUB_REASON AS SUBREASON
    FROM {{ ref('shipment_penalties_master') }}

    UNION ALL

    SELECT 'N/A' AS SUBREASON
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SUBREASON
