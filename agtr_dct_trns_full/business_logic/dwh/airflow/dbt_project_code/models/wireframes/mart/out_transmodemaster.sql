-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
TRANSMODE_MASTER AS (
    SELECT DISTINCT
        TRANSMODETYPE AS CATEGORY,
        TRANSMODE,
        TRANSMODEDESCRIPTION AS "DESCRIPTION"
    FROM {{ ref('transmode_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM TRANSMODE_MASTER
