-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
CREDITOR_MASTER AS (
    SELECT DISTINCT COALESCE(CREDITOR, 'N/A') AS CREDITOR
    FROM {{ ref('port_swap_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM CREDITOR_MASTER
