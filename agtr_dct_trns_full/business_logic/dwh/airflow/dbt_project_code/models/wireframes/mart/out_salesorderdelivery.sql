-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf43']
    )
}}

WITH
SALES_ORDER AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        SO.ITEM,
        SO.LOCATION,
        SO.DEMANDID,
        SO.CUSTOMERID AS CUSTOMER,
        NULL AS SALES_CHANNEL,
        SO.FREIGHTTYPE AS OPERATION_TYPE,
        CASE
            WHEN IT.L3 = 'OUTBOUND' AND SO.OPERATIONTYPE = 'VEN'
                THEN 'Mercado Interno'
            WHEN IT.L3 = 'OUTBOUND' AND SO.OPERATIONTYPE = 'TRF'
                THEN 'Transferência'
            WHEN IT.L3 = 'OUTBOUND' AND SO.OPERATIONTYPE = 'EXP'
                THEN 'Exportação'
            WHEN IT.L3 != 'OUTBOUND'
                THEN 'Sales Order Delivery'
            ELSE ''
        END AS DEMAND_TYPE,
        TO_CHAR(
            TRY_TO_DATE(SO.SALESORDERCOMMITDATE, 'DD-MM-YYYY'),
            'DD-MON-YY'
        ) AS "DAY",
        TO_CHAR(
            TRY_TO_DATE(SO.SALESORDERCOMMITDATE, 'DD-MM-YYYY'),
            'DD-MON-YY'
        ) AS SO_COMMITTED_DATE,
        TO_CHAR(
            TRY_TO_DATE(SO.SALESORDERCOMMITDATE, 'DD-MM-YYYY'),
            'DD-MON-YY'
        ) AS SO_DELIVERY_DATE,
        MAX(TO_CHAR(
            TRY_TO_DATE(SO.LASTCHANGEDDATEOFSALESORDER, 'DD-MM-YYYY'),
            'DD-MON-YY'
        )) AS SO_LAST_UPDATED_DATE,
        MAX(TO_CHAR(
            TRY_TO_DATE(SO.CREATIONDATEOFSALESORDERDOCUMENT, 'DD-MM-YYYY'),
            'DD-MON-YY'
        )) AS SO_DOCUMENT_CREATION_DATE,
        SUM(SO.DELIVEREDSALESORDERQUANTITY) AS SO_DELIVERED_QTY,
        SUM(SO.COMMITTEDSALESORDERQUANTITY) AS SO_COMMITTED_QTY,
        MAX(SO.LTA) AS LTA,
        (
            SUM(SO.COMMITTEDSALESORDERQUANTITY)
            - SUM(SO.DELIVEREDSALESORDERQUANTITY)
        ) AS QUANTITY_GAP,
        SUM(SO.BLOCKEDQUANTITY) AS SO_BLOCKED_QTY
    FROM {{ ref('sales_order_delivery_master') }} AS SO
    INNER JOIN {{ ref('item_master') }} AS IT
        ON SO.ITEM = IT.ITEM
    WHERE
        1 = 1
        AND SO.SALESORDERCOMMITDATE != ''
        AND IT.L3 = 'INBOUND'
    GROUP BY
        SO.ITEM,
        SO.LOCATION,
        SO.DEMANDID,
        SO.CUSTOMERID,
        SO.SALESORDERCOMMITDATE,
        SO.FREIGHTTYPE,
        IT.L3,
        SO.OPERATIONTYPE
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SALES_ORDER
