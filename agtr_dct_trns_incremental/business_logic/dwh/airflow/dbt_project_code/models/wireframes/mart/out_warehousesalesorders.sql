-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf_warehousesalesorders']
    )
}}

WITH
WAREHOUSE AS (
    SELECT DISTINCT
        'CurrentWorkingView' AS VERSION_NAME,
        A.DEMANDID,
        '1' AS WAREHOUSESALESORDERS
    FROM {{ ref('sales_order_delivery_master') }} AS A
    INNER JOIN {{ ref('location_master') }} AS B
        ON A.LOCATION = B.LOCATIONID
    WHERE
        B.LOCATION_UNIT_STRUCTURE != 'PONTO DE COLETA'
        AND (
            TRY_TO_DATE(A.SALESORDERCOMMITDATE, 'DD-MM-YYYY') BETWEEN
            -- first day of last 2 years and last day of next year
            DATE_TRUNC(YEAR, DATEADD(YEAR, -2, CURRENT_DATE()))
            AND LAST_DAY(DATEADD(YEAR, 1, CURRENT_DATE()), YEAR)
        )
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM WAREHOUSE
