-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf41b']
    )
}}

WITH
SHIPMENTSDATA AS (
    SELECT
        A.ITEM,
        A.SOURCE,
        A.ACTUALSHIPDATE,
        A.ESTIMATEDSHIPDATE,
        C.CUSTOMERID,
        A.SOURCINGCONTRACTNUMBER,
        A.SALESORDERDELIVERYID,
        A.QUANTITY,
        A.QUALITYADJUSTMENT,
        CASE
            WHEN E.LOCATION_UNIT_STRUCTURE IN ('TRANSBORDO', 'PORTO FLUVIAL')
                THEN E.LOCATION_CODE
            ELSE 'ROD'
        END AS TRANSMODE,
        CASE
            WHEN E.LOCATION_UNIT_STRUCTURE IN ('TRANSBORDO', 'PORTO FLUVIAL')
                THEN A.DESTINATIONLOCATION
            ELSE 'N/A'
        END AS TRANSSHIPMENT,
        CASE
            WHEN
                A.OPERATIONTYPE IN ('FBZ', 'FOB')
                AND COALESCE(C.CUSTOMERID, 'N/A') != 'N/A'
                THEN 'VENDAS'
            ELSE A.OPERATIONTYPE
        END AS OPERATIONTYPE,
        CASE
            WHEN
                (
                    A.OPERATIONTYPE = 'FBZ'
                    AND E.LOCATION_UNIT_STRUCTURE NOT IN (
                        'TRANSBORDO', 'PORTO FLUVIAL'
                    )
                ) OR A.OPERATIONTYPE IN ('CIF', 'FOB')
                THEN A.DESTINATIONLOCATION
            ELSE A.FINALDESTINATION
        END AS FINALDESTINATION,
        IFF(A.SOURCINGCONTRACTNUMBER != 'N/A', F.SUPPLIERID, 'N/A') AS SUPPLIER
    FROM {{ ref('intstg_shipment_details') }} AS A
    INNER JOIN {{ ref('intstg_shipment_latest_status') }} AS B
        ON A.ID = B.ID
    LEFT JOIN {{ ref('sales_order_delivery_master') }} AS C
        ON A.SALESORDERDELIVERYID = C.DEMANDID
    LEFT JOIN {{ ref('location_master') }} AS E
        ON A.DESTINATIONLOCATION = E.LOCATIONID
    LEFT JOIN {{ ref('sourcing_contract_details_master') }} AS F
        ON A.SOURCINGCONTRACTNUMBER = F.ID
    WHERE
        B.LATESTSTATUS != 'CANCELLED'
        AND A.OPERATIONTYPE IN ('CIF', 'FOB', 'FBZ', 'TRF', 'VEN')
),

CIFDATA AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATIONTYPE AS OPERATION_TYPE,
        ACTUALSHIPDATE AS "DAY",
        FINALDESTINATION AS "LOCATION",
        SUPPLIER,
        0 AS SCHEDULEDQTY,
        COALESCE(
            CASE
                WHEN OPERATIONTYPE IN ('CIF', 'FOB', 'FBZ')
                    THEN CUSTOMERID
                ELSE 'N/A'
            END, 'N/A'
        ) AS CUSTOMER,
        SUM(QUANTITY) AS EXECUTEDQTY
    FROM SHIPMENTSDATA
    WHERE
        OPERATIONTYPE IN ('CIF', 'FOB', 'FBZ', 'TRF')
        AND ACTUALSHIPDATE IS NOT NULL
    GROUP BY
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATIONTYPE,
        ACTUALSHIPDATE,
        CUSTOMERID,
        FINALDESTINATION,
        SUPPLIER
),

VENDATA AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        'VENDAS' AS OPERATION_TYPE,
        ACTUALSHIPDATE AS "DAY",
        'N/A' AS "LOCATION",
        SUPPLIER,
        0 AS SCHEDULEDQTY,
        COALESCE(CUSTOMERID, 'N/A') AS CUSTOMER,
        SUM(QUANTITY) AS EXECUTEDQTY
    FROM SHIPMENTSDATA
    WHERE
        OPERATIONTYPE = 'VEN'
        AND SALESORDERDELIVERYID IS NOT NULL
        AND ACTUALSHIPDATE IS NOT NULL
    GROUP BY
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATIONTYPE,
        ACTUALSHIPDATE,
        CUSTOMERID,
        SUPPLIER
),

SHIPRESULT AS (
    SELECT
        VERSION_NAME,
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATION_TYPE,
        "DAY",
        CUSTOMER,
        "LOCATION",
        SUPPLIER,
        EXECUTEDQTY,
        SCHEDULEDQTY
    FROM CIFDATA

    UNION ALL

    SELECT
        VERSION_NAME,
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATION_TYPE,
        "DAY",
        CUSTOMER,
        "LOCATION",
        SUPPLIER,
        EXECUTEDQTY,
        SCHEDULEDQTY
    FROM VENDATA
),

OUT_TEMP AS (
    SELECT
        VERSION_NAME,
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATION_TYPE,
        CUSTOMER,
        "LOCATION",
        -- SUPPLIER,
        SUM(EXECUTEDQTY)::DECIMAL(20, 3) AS ACTUALS_QTY_SOURCE,
        SUM(SCHEDULEDQTY)::DECIMAL(20, 3) AS SCHEDULED_QTY_SOURCE,
        TO_CHAR("DAY", 'DD-MON-YY') AS "DAY"
    FROM SHIPRESULT
    WHERE "DAY" IS NOT NULL
    GROUP BY
        VERSION_NAME,
        ITEM,
        SOURCE,
        TRANSMODE,
        TRANSSHIPMENT,
        OPERATION_TYPE,
        CUSTOMER,
        "LOCATION",
        -- SUPPLIER,
        "DAY"
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM OUT_TEMP
