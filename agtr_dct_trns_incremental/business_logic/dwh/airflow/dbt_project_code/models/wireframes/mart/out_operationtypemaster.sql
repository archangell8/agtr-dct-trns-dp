-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
OPERATION_TYPE AS (
    SELECT DISTINCT OPERATIONTYPE
    FROM {{ ref('shipment_details_master') }}

    UNION DISTINCT

    SELECT DISTINCT OPERATION AS OPERATIONTYPE
    FROM {{ ref('distribution_ibp_master') }}

    UNION DISTINCT

    SELECT 'VENDAS' AS OPERATIONTYPE
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM OPERATION_TYPE
