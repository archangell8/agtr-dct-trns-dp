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
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM REASON
