-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf06']
    )
}}

WITH
CTE_SHIPMENT_STATUS AS (
    SELECT DISTINCT
        SHIPMENTID,
        STATUS,
        TO_DATE(STATUSREFERENCEDATE, 'DD-MM-YYYY') AS STATUSREFERENCEDATE
    FROM {{ ref('shipment_status_quality_details_master') }}
    WHERE STATUS IN ('LOADING ORDER', 'IN SOURCE', 'INVOICE')
),

CTE_OC_DELAYED AS (
    SELECT
        S.ITEM,
        S.OPERATIONTYPE,
        S.SOURCE,
        S.CARRIER,
        S.DESTINATIONLOCATION,
        S.SOURCINGCONTRACTNUMBER,
        S.SALESORDERDELIVERYID,
        S.FINALDESTINATION,
        S.NUMERO_OC AS OC_DELAYED,
        CURRENT_DATE() AS "DAY"
    FROM {{ ref('intstg_shipment_details_without_cancelled_shipments') }} AS S
    LEFT JOIN {{ ref('intstg_shipment_latest_status') }} AS SSL
        ON S.SHIPMENTLINEID = SSL.SHIPMENTLINEID
    LEFT JOIN {{ ref('tab_shipment_ctms_oc_stg') }} AS SOC
        ON S.NUMERO_OC = SOC.NUMERO_OC
    WHERE
        1 = 1
        AND SSL.LATESTSTATUSDATE < CURRENT_DATE()
        AND SSL.LATESTSTATUS = 'LOADING ORDER'
        AND S.NUMERO_OC IS NOT NULL
        AND SOC.STATUS_OC != 'OC CANCELADA'
),

CTE_OC_EMIT AS (
    SELECT
        S.ITEM,
        S.OPERATIONTYPE,
        S.SOURCE,
        S.CARRIER,
        S.DESTINATIONLOCATION,
        S.SOURCINGCONTRACTNUMBER,
        S.SALESORDERDELIVERYID,
        S.FINALDESTINATION,
        S.DATA_EMISSAO_OC::DATE AS "DAY",
        S.NUMERO_OC AS OC_EMIT
    FROM {{ ref('intstg_shipment_details_without_cancelled_shipments') }} AS S
    LEFT JOIN {{ ref('tab_shipment_ctms_oc_stg') }} AS SOC
        ON S.NUMERO_OC = SOC.NUMERO_OC
    WHERE
        1 = 1
        AND S.NUMERO_OC IS NOT NULL
        AND SOC.STATUS_OC != 'OC CANCELADA'
),

CTE_SOURCE_INVOICE AS (
    SELECT
        S.ITEM,
        S.OPERATIONTYPE,
        S.SOURCE,
        S.CARRIER,
        S.DESTINATIONLOCATION,
        S.SOURCINGCONTRACTNUMBER,
        S.SALESORDERDELIVERYID,
        S.FINALDESTINATION,
        SS.STATUSREFERENCEDATE AS "DAY",
        CASE
            WHEN SS.STATUS = 'LOADING ORDER'
                THEN S.SHIPMENTLINEID
        END AS LOADING_ORDER,
        CASE
            WHEN SS.STATUS = 'IN SOURCE'
                THEN S.SHIPMENTLINEID
        END AS CHECKIN,
        CASE
            WHEN SS.STATUS = 'INVOICE'
                THEN S.SHIPMENTLINEID
        END AS INVOICE
    FROM {{ ref('intstg_shipment_details_without_cancelled_shipments') }} AS S
    INNER JOIN CTE_SHIPMENT_STATUS AS SS
        ON S.ID = SS.SHIPMENTID
    WHERE
        1 = 1
),

EXECUTED_TEMP_1 AS (
    SELECT
        ITEM,
        OPERATIONTYPE,
        SOURCE,
        CARRIER,
        DESTINATIONLOCATION,
        "DAY",
        SOURCINGCONTRACTNUMBER,
        SALESORDERDELIVERYID,
        FINALDESTINATION,
        OC_DELAYED,
        NULL AS OC_EMIT,
        NULL AS LOADING_ORDER,
        NULL AS CHECKIN,
        NULL AS INVOICE
    FROM CTE_OC_DELAYED

    UNION ALL

    SELECT
        ITEM,
        OPERATIONTYPE,
        SOURCE,
        CARRIER,
        DESTINATIONLOCATION,
        "DAY",
        SOURCINGCONTRACTNUMBER,
        SALESORDERDELIVERYID,
        FINALDESTINATION,
        NULL AS OC_DELAYED,
        OC_EMIT,
        NULL AS LOADING_ORDER,
        NULL AS CHECKIN,
        NULL AS INVOICE
    FROM CTE_OC_EMIT

    UNION ALL

    SELECT
        ITEM,
        OPERATIONTYPE,
        SOURCE,
        CARRIER,
        DESTINATIONLOCATION,
        "DAY",
        SOURCINGCONTRACTNUMBER,
        SALESORDERDELIVERYID,
        FINALDESTINATION,
        NULL AS OC_DELAYED,
        NULL AS OC_EMIT,
        LOADING_ORDER,
        CHECKIN,
        INVOICE
    FROM CTE_SOURCE_INVOICE
),

EXECUTED_TEMP AS (
    SELECT
        S.ITEM,
        S.OPERATIONTYPE,
        S.SOURCE,
        S.CARRIER,
        S.DAY,
        S.OC_DELAYED,
        S.OC_EMIT,
        S.LOADING_ORDER,
        S.CHECKIN,
        S.INVOICE,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN S.DESTINATIONLOCATION
            ELSE 'N/A'
        END AS TRANSSHIPMENT,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN S.FINALDESTINATION
            ELSE S.DESTINATIONLOCATION
        END AS "LOCATION",
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN LD.LOCATION_CODE
            ELSE 'N/A'
        END AS TRANSMODE,
        IFF(
            SC.ID IS NOT NULL,
            SC.SUPPLIERID,
            'N/A'
        ) AS SUPPLIERID,
        IFF(
            SOD.DEMANDID IS NOT NULL,
            SOD.CUSTOMERID,
            'N/A'
        ) AS CUSTOMER
    FROM EXECUTED_TEMP_1 AS S
    INNER JOIN {{ ref('location_master') }} AS LD
        ON S.DESTINATIONLOCATION = LD.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LOCS
        ON S.SOURCE = LOCS.LOCATIONID
    LEFT JOIN {{ ref('sourcing_contract_details_master') }} AS SC
        ON S.SOURCINGCONTRACTNUMBER = SC.ID
    LEFT JOIN {{ ref('sales_order_delivery_master') }} AS SOD
        ON S.SALESORDERDELIVERYID = SOD.DEMANDID
    WHERE
        1 = 1
        AND LOCS.LOCATION_UNIT_STRUCTURE IN (
            'PONTO DE COLETA', 'ARMAZÉM', 'FÁBRICA'
        )
),

EXECUTED AS (
    SELECT
        ITEM,
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        DAY,
        NULL AS PLANNED,
        COUNT(OC_DELAYED) AS OC_DELAYED,
        COUNT(OC_EMIT) AS OC_EMIT,
        COUNT(LOADING_ORDER) AS LOADING_ORDER,
        COUNT(CHECKIN) AS CHECKIN,
        COUNT(INVOICE) AS INVOICE
    FROM EXECUTED_TEMP
    GROUP BY
        ITEM,
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        DAY
),

SCHEDULED_TEMP AS (
    SELECT
        TS.ITEM,
        TS.TYPE AS OPERATIONTYPE,
        TS.SOURCE,
        TRIM(CASE
            WHEN TS.CARRIER LIKE '%-%'
                THEN SPLIT_PART(TS.CARRIER, '-', 1)
            ELSE TS.CARRIER
        END) AS CARRIER,
        TO_DATE(TS.DATE, 'DD-MM-YYYY') AS DAY,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN TS.FINALDESTINATION
            ELSE TS.DESTINATION
        END AS "LOCATION",
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN TS.DESTINATION
            ELSE 'N/A'
        END AS TRANSSHIPMENT,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN LD.LOCATION_CODE
            ELSE 'ROD'
        END AS TRANSMODE,
        IFF(
            SC.ID IS NOT NULL,
            SC.SUPPLIERID,
            'N/A'
        ) AS SUPPLIERID,
        IFF(
            SOD.DEMANDID IS NOT NULL,
            SOD.CUSTOMERID,
            'N/A'
        ) AS CUSTOMER,
        --Creates an aprox number of loads based on the scheduled volume
        ROUND(TS.VOLUME / 44, 0) AS QTY_OF_LOADS
    FROM {{ ref('transportation_schedule_master') }} AS TS
    INNER JOIN {{ ref('location_master') }} AS LD
        ON TS.DESTINATION = LD.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LOCS
        ON TS.SOURCE = LOCS.LOCATIONID
    LEFT JOIN {{ ref('sourcing_contract_details_master') }} AS SC
        ON TS.SOURCINGCONTRACT = SC.ID
    LEFT JOIN {{ ref('sales_order_delivery_master') }} AS SOD
        ON TS.SALESORDERDELIVERYID = SOD.DEMANDID
    WHERE
        1 = 1
        AND LOCS.LOCATION_UNIT_STRUCTURE IN (
            'PONTO DE COLETA', 'ARMAZÉM', 'FÁBRICA'
        )
),

SCHEDULED AS (
    SELECT
        ITEM,
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        DAY,
        NULL AS OC_DELAYED,
        NULL AS OC_EMIT,
        NULL AS LOADING_ORDER,
        NULL AS CHECKIN,
        NULL AS INVOICE,
        SUM(QTY_OF_LOADS) AS PLANNED
    FROM SCHEDULED_TEMP
    GROUP BY
        ITEM,
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        DAY
),

EXEC_PLANNED_TEMP AS (
    SELECT
        ITEM,
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        DAY,
        COALESCE(PLANNED, 0) AS PLANNED,
        COALESCE(OC_DELAYED, 0) AS OC_DELAYED,
        COALESCE(OC_EMIT, 0) AS OC_EMIT,
        COALESCE(LOADING_ORDER, 0) AS LOADING_ORDER,
        COALESCE(CHECKIN, 0) AS CHECKIN,
        COALESCE(INVOICE, 0) AS INVOICE
    FROM EXECUTED

    UNION ALL

    SELECT
        ITEM,
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        DAY,
        COALESCE(PLANNED, 0) AS PLANNED,
        COALESCE(OC_DELAYED, 0) AS OC_DELAYED,
        COALESCE(OC_EMIT, 0) AS OC_EMIT,
        COALESCE(LOADING_ORDER, 0) AS LOADING_ORDER,
        COALESCE(CHECKIN, 0) AS CHECKIN,
        COALESCE(INVOICE, 0) AS INVOICE
    FROM SCHEDULED
),

EXEC_PLANNED AS (
    SELECT
        S.ITEM,
        S.TRANSSHIPMENT,
        S.OPERATIONTYPE,
        S.SUPPLIERID,
        S.SOURCE,
        S.TRANSMODE,
        S.CARRIER,
        S.CUSTOMER,
        S.DAY,
        S.LOCATION,
        SUM(S.PLANNED) AS PLANNED,
        SUM(S.OC_DELAYED) AS OC_DELAYED,
        SUM(S.OC_EMIT) AS OC_EMIT,
        SUM(S.LOADING_ORDER) AS LOADING_ORDER,
        SUM(S.CHECKIN) AS CHECKIN,
        SUM(S.INVOICE) AS INVOICE
    FROM EXEC_PLANNED_TEMP AS S
    GROUP BY
        S.ITEM,
        S.TRANSSHIPMENT,
        S.LOCATION,
        S.OPERATIONTYPE,
        S.SUPPLIERID,
        S.SOURCE,
        S.TRANSMODE,
        S.CARRIER,
        S.CUSTOMER,
        S.DAY
)

SELECT
    ITEM,
    TRANSSHIPMENT,
    LOCATION,
    OPERATIONTYPE,
    SUPPLIERID,
    SOURCE,
    TRANSMODE,
    CARRIER,
    CUSTOMER,
    DAY,
    PLANNED,
    OC_DELAYED,
    OC_EMIT,
    LOADING_ORDER,
    CHECKIN,
    INVOICE
FROM EXEC_PLANNED
WHERE
    1 = 1
    AND (
        PLANNED > 0 OR OC_DELAYED > 0 OR OC_EMIT > 0
        OR CHECKIN > 0 OR INVOICE > 0 OR LOADING_ORDER > 0
    )
