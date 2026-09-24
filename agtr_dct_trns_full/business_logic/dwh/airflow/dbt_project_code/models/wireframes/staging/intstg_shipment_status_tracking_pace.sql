-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf06']
    )
}}

WITH
TEMP_CMM AS (
    SELECT --noqa
        ITEM,
        SOURCE,
        DESTINATION,
        TYPE,
        'ROD' AS TRANSMODE,
        'PLANNED' AS STATUS,
        TRY_TO_DATE(DATE, 'DD-MM-YYYY') AS DAY,
        TRIM(CASE
            WHEN CARRIER LIKE '%-%'
                THEN SPLIT_PART(CARRIER, '-', 1)
            ELSE CARRIER
        END) AS CARRIER,
        COUNT(*) AS NUMB_LOADS,
        SUM(VOLUME)::DECIMAL(20, 3) AS SHIPMENTQTY
    FROM {{ ref('transportation_schedule_master') }}
    GROUP BY
        ITEM,
        SOURCE,
        DESTINATION,
        TYPE,
        TRY_TO_DATE(DATE, 'DD-MM-YYYY'),
        CARRIER
),

SHIPMENTSTATUS_MASTER AS (
    SELECT DISTINCT
        SHIPMENTID,
        STATUSREFERENCEDATE AS REFERENCEDATE,
        STATUS,
        QUANTITY::DECIMAL(20, 3) AS QUANTITY
    FROM {{ ref('shipment_status_quality_details_master') }}
),

TEMP_ALLSTATUS AS (
    SELECT
        A.ITEM,
        A.SOURCELOCATION,
        A.DESTINATIONLOCATION,
        A.TRANSMODE,
        A.OPERATIONTYPE,
        B.STATUS,
        TRY_TO_DATE(B.REFERENCEDATE, 'DD-MM-YYYY') AS DAY,
        TRIM(CASE
            WHEN A.CARRIER LIKE '%-%'
                THEN SPLIT_PART(A.CARRIER, '-', 1)
            ELSE A.CARRIER
        END) AS CARRIER,
        COUNT(A.SHIPMENTLINEID) AS NUMB_LOADS,
        SUM(COALESCE(B.QUANTITY, A.QUANTITY)) AS SHIPMENTQTY
    FROM {{ ref('intstg_shipment_details_without_cancelled_shipments') }} AS A
    INNER JOIN SHIPMENTSTATUS_MASTER AS B
        ON A.ID = B.SHIPMENTID
    WHERE
        1 = 1
        AND A.TRANSMODE = 'ROD'
    GROUP BY
        A.ITEM,
        A.SOURCELOCATION,
        A.DESTINATIONLOCATION,
        A.TRANSMODE,
        A.OPERATIONTYPE,
        B.STATUS,
        B.REFERENCEDATE,
        A.CARRIER
),

TEMP_ALLSTATUS_CARRIER AS (
    SELECT DISTINCT CARRIER
    FROM TEMP_ALLSTATUS
),

TEMP_JOINED AS (
    -- Planned loads
    SELECT
        A.ITEM,
        A.SOURCE,
        A.DESTINATION,
        A.TRANSMODE,
        A.TYPE,
        A.STATUS,
        A.DAY,
        A.SHIPMENTQTY,
        A.NUMB_LOADS,
        CASE
            WHEN
                B.CARRIER IS NULL
                THEN 'N/A'
            ELSE A.CARRIER
        END AS CARRIER
    FROM TEMP_CMM AS A
    LEFT JOIN TEMP_ALLSTATUS_CARRIER AS B
        ON A.CARRIER = B.CARRIER

    UNION ALL

    -- Actual shipment statuses
    SELECT
        ITEM,
        SOURCELOCATION,
        DESTINATIONLOCATION,
        TRANSMODE,
        OPERATIONTYPE,
        STATUS,
        DAY,
        SHIPMENTQTY,
        NUMB_LOADS,
        CARRIER
    FROM TEMP_ALLSTATUS
    WHERE
        1 = 1
        AND STATUS IN ('LOADING ORDER', 'IN SOURCE', 'INVOICE')
)

SELECT
    ITEM,
    SOURCE,
    DESTINATION,
    TRANSMODE,
    TYPE,
    STATUS,
    DAY,
    CARRIER,
    SHIPMENTQTY,
    NULL AS PACE,
    NUMB_LOADS AS NUMBER_OF_SHIPMENTS
FROM TEMP_JOINED
