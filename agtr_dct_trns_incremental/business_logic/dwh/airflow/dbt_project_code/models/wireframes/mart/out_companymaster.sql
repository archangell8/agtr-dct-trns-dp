-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
COMPANYMASTER AS (
    SELECT DISTINCT COMPANY
    FROM {{ ref('onhands_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM COMPANYMASTER
