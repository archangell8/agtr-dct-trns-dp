-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf_sobpassociation']
    )
}}

WITH
CTE_SALES_ORDER_DELIVERY AS (
    SELECT
        DEMANDID,
        ITEM,
        SOURCEBP,
        TRY_TO_DATE(SALESORDERCOMMITDATE, 'DD-MM-YYYY') AS COMMITDATE
    FROM {{ ref('sales_order_delivery_master') }}
),

SPBP_ASSOCIATION AS (
    SELECT DISTINCT
        'CurrentWorkingView' AS VERSION_NAME,
        B.DEMANDID,
        1 AS SO_BP_ASSOCIATION,
        SPLIT_PART(A.ID, '-', 2) AS CONTRACT_LINEID
    FROM {{ ref('intstg_sourcing_contract_details') }} AS A
    INNER JOIN CTE_SALES_ORDER_DELIVERY AS B
        ON
            A.ORIGINATIONLOCATION = B.SOURCEBP
            AND A.ITEM = B.ITEM
    WHERE
        UPPER(A.CONTRACTSTATUS) = 'ACTIVE'
        -- Sales order date must be bigger or equal to first day of the
        -- past 2 years
        AND B.COMMITDATE >= DATE_TRUNC(YEAR, DATEADD(YEAR, -2, CURRENT_DATE()))
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SPBP_ASSOCIATION
