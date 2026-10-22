-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
TYPE_MASTER AS (
    SELECT DISTINCT TYPE
    FROM {{ ref('distribution_ibp_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM TYPE_MASTER
