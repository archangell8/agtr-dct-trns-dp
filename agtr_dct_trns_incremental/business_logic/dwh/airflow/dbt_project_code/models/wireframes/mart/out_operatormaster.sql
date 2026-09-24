-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
OPERATOR_MASTER AS (
    SELECT DISTINCT OPERATOR
    FROM {{ ref('intstg_originsnoe') }}

    UNION DISTINCT

    SELECT DISTINCT OPERATOR
    FROM {{ ref('intstg_destinationsnoe') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM OPERATOR_MASTER
