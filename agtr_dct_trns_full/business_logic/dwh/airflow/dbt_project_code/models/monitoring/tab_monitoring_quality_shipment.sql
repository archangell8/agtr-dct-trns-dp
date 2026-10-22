--noqa: disable=RF04
{{
    config(
        materialized='table'
    )
}}

WITH
/* ----------------------------VOLUME VALIDATION---------------------------- */
VOLUME_E1 AS (
    SELECT
        F.PURCHASE_CODE::STRING AS PURCHASE_CODE,
        SUM(
            IFF(F.APPLIED_VOLUME = 0, F.INVOICE_VOLUME, F.APPLIED_VOLUME) / 1000
        )::DECIMAL(20, 3) AS VOLUMEE1
    FROM {{ ref('tab_shipment_fichas_jde_stg') }} AS F
    INNER JOIN {{ ref('item') }} AS I
        ON F.PRODUCT_CODE = I.ITEM
    WHERE
        1 = 1
        AND I.ITEMSTAGE = 'GRAOS'
        AND F.PURCHASE_STATUS_CODE != '980-999'
        AND F.LOAD_NUMBER IS NULL
        AND F.OPERATION_TYPE IN ('CIF', 'FOB')
    GROUP BY PURCHASE_CODE
),

VOLUME_SHIPMENT AS (
    SELECT
        S.LOADNUMBER::STRING AS LOADNUMBER,
        SUM(COALESCE(S.QUANTITY, 0))::DECIMAL(20, 3) AS VOLUMESHIP
    FROM {{ ref('shipment_details') }} AS S
    INNER JOIN {{ ref('item') }} AS I
        ON S.ITEMID = I.ITEM
    LEFT JOIN {{ ref('shipment_status_quality_details') }} AS T
        ON
            S.ID = T.SHIPMENTID
            AND T.STATUS = 'CANCELLED'
    WHERE
        1 = 1
        AND S.ACTUALSHIPDATE != 'N/A'
        AND T.SHIPMENTID IS NULL
        AND I.ITEMSTAGE = 'GRAOS'
    GROUP BY S.LOADNUMBER
),

VOLUME_VALIDATION AS (
    SELECT
        'SHIPMENT_DETAILS' AS ENTITY,
        S.LOADNUMBER AS ENTITY_KEY,
        'QUANTITY' AS FIELD_NOT_OK,
        S.VOLUMESHIP AS VALUE_NOT_OK,
        CONCAT('DOES NOT MATCH WITH SOURCE VOLUME ', E.VOLUMEE1) AS COMMENTS
    FROM VOLUME_E1 AS E
    INNER JOIN VOLUME_SHIPMENT AS S
        ON E.PURCHASE_CODE = S.LOADNUMBER
    WHERE
        1 = 1
        AND NOT E.PURCHASE_CODE IN (
            78554360, 78622884, 78575379, 78397939, 1743015
        )
        AND E.VOLUMEE1 != S.VOLUMESHIP
),

/* -----------------------"BARCAÇA" PLATE VALIDATION----------------------- */
PLATE_VALIDATION AS (
    SELECT
        'SHIPMENT_DETAILS' AS ENTITY,
        S.ID AS ENTITY_KEY,
        'VEHICLEID' AS FIELD_NOT_OK,
        S.VEHICLEID AS VALUE_NOT_OK,
        CONCAT(
            'WRONG PLATE REGISTERED ', S.VEHICLEID,
            ' ON LOADNUMBER ', S.LOADNUMBER
        ) AS COMMENTS
    FROM {{ ref('shipment_details') }} AS S
    INNER JOIN {{ ref('location') }} AS L
        ON S.SOURCE = L.LOCATIONID
    WHERE
        S.ACTUALSHIPDATE != 'N/A'
        AND L.LOCATION_UNIT_STRUCTURE = 'PORTO FLUVIAL'
        AND S.TRANSMODE = 'ROD'
        AND S.OPERATIONTYPE = 'TRF'
        AND NOT EXISTS (
            SELECT 1
            FROM {{ ref('shipment_status_quality_details') }} AS T
            WHERE
                S.ID = T.SHIPMENTID
                AND T.STATUS = 'CANCELLED'
        )
),

QUALITY_VALIDATION AS (
    SELECT
        ENTITY,
        ENTITY_KEY,
        FIELD_NOT_OK,
        VALUE_NOT_OK,
        COMMENTS
    FROM VOLUME_VALIDATION

    UNION ALL

    SELECT
        ENTITY,
        ENTITY_KEY,
        FIELD_NOT_OK,
        VALUE_NOT_OK,
        COMMENTS
    FROM PLATE_VALIDATION
)

SELECT
    *,
    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()) AS TIMESTAMP_EXECUTION
FROM QUALITY_VALIDATION
