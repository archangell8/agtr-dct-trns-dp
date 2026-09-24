-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
DEBITOR_MASTER AS (
    SELECT DISTINCT DEBITOR
    FROM {{ ref('port_swap_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM DEBITOR_MASTER
