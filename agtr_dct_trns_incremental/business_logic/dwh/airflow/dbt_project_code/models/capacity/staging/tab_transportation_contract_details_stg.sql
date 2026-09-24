-- noqa: disable=RF06, TMP
{{
    config(
        materialized='table',
        post_hook=[
            """
                INSERT INTO tab_transportationcontract_control_id
                SELECT
                    BK_ID,
                    {{ target.database }}.{{ target.schema }}.SEQ_ID_TRANSPORTATIONCONTRACT.NEXTVAL AS TRANSPORTATIONCONTRACTID
                FROM {{ this }}
                WHERE BK_ID NOT IN (
                    SELECT BK_ID FROM {{ ref('tab_transportationcontract_control_id') }}
                )
            """,
            """
                UPDATE {{ this }}
                SET TRANSPORTATIONCONTRACTID = TB_CONTROL.TRANSPORTATIONCONTRACTID
                FROM (
                    SELECT BK_ID, MIN(TRANSPORTATIONCONTRACTID) AS TRANSPORTATIONCONTRACTID
                    FROM {{ ref('tab_transportationcontract_control_id') }}
                    GROUP BY BK_ID
                ) AS TB_CONTROL
                WHERE {{ this }}.BK_ID = TB_CONTROL.BK_ID
            """,
            """
                INSERT INTO tab_transportationcontractline_control_id
                SELECT
                    BK_LINEID,
                    {{ target.database }}.{{ target.schema }}.SEQ_ID_TRANSPORTATIONCONTRACTLINE.NEXTVAL AS TRANSPORTATIONCONTRACTLINEID
                FROM {{ this }}
                WHERE BK_LINEID NOT IN (
                    SELECT BK_LINEID FROM {{ ref('tab_transportationcontractline_control_id') }}
                )
            """,
            """
                UPDATE {{ this }}
                SET TRANSPORTATIONCONTRACTLINEID = TB_CONTROL.TRANSPORTATIONCONTRACTLINEID
                FROM (
                    SELECT BK_LINEID, MIN(TRANSPORTATIONCONTRACTLINEID) AS TRANSPORTATIONCONTRACTLINEID
                    FROM {{ ref('tab_transportationcontractline_control_id') }}
                    GROUP BY BK_LINEID
                ) AS TB_CONTROL
                WHERE {{ this }}.BK_LINEID = TB_CONTROL.BK_LINEID
            """
        ]
    )
}}

WITH
UDC AS ( --noqa
    SELECT
        CATEGORY,
        STAGE,
        SOURCE_CODE,
        TARGET_CODE
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
    WHERE
        1 = 1
        AND STATUS = 'ATIVO'
        AND CATEGORY = 'TRANSPORTATIONCONTRACTDETAILS'
),

TCD_TEMP AS (
    SELECT
        NULL AS TRANSPORTATIONCONTRACTID,
        NULL AS TRANSPORTATIONCONTRACTLINEID,
        MINTOLERANCE,
        SOURCE,
        DESTINATION,
        ITEMID,
        PENALTYFEE,
        TRANSMODE,
        TRANSMODETYPE,
        STARTDATE,
        ENDDATE,
        QUANTITY,
        TOPRATE,
        UOM,
        COMMENTS,
        PAIDPENALTY,
        CURRENCY,
        DATA_SOURCE
    FROM {{ source('pscfl', 'F_MIN_TRANSPORTATIONCONTRACTDETAILS_CAPACITY') }}
    WHERE TO_DATE(STARTDATE, 'DD-MM-YYYY') > '2025-01-01'::DATE

    UNION DISTINCT

    SELECT
        NULL AS TRANSPORTATIONCONTRACTID,
        NULL AS TRANSPORTATIONCONTRACTLINEID,
        MINTOLERANCE,
        SOURCE,
        DESTINATION,
        ITEMID,
        PENALTYFEE,
        TRANSMODE,
        TRANSMODETYPE,
        STARTDATE,
        ENDDATE,
        QUANTITY,
        TOPRATE,
        UOM,
        COMMENTS,
        PAIDPENALTY,
        CURRENCY,
        DATA_SOURCE
    FROM {{ source('pscfl', 'F_MIN_TRANSPORTATIONCONTRACTDETAILS_RAIL') }}
    WHERE TO_DATE(STARTDATE, 'DD-MM-YYYY') >= '2025-01-01'::DATE
),

TCD_TRNS AS (
    SELECT
        TCD.TRANSPORTATIONCONTRACTID,
        TCD.TRANSPORTATIONCONTRACTLINEID,
        TCD.MINTOLERANCE,
        ORIG.TARGET_CODE AS SOURCE,
        DEST.TARGET_CODE AS DESTINATION,
        ITM.TARGET_CODE AS ITEMID,
        TCD.PENALTYFEE,
        'N/A' AS LANEID,
        TRANS.TARGET_CODE AS TRANSMODE,
        TCD.TRANSMODETYPE,
        TCD.STARTDATE,
        TCD.ENDDATE,
        TCD.QUANTITY,
        TCD.TOPRATE,
        TCD.UOM,
        TCD.COMMENTS,
        0 AS PAIDPENALTY,
        TCD.CURRENCY,
        TCD.DATA_SOURCE,
        CONCAT(ORIG.TARGET_CODE, DEST.TARGET_CODE) AS BK_ID,
        CONCAT(
            ORIG.TARGET_CODE, DEST.TARGET_CODE, ITM.TARGET_CODE
        ) AS BK_LINEID
    FROM TCD_TEMP AS TCD
    INNER JOIN UDC AS TRANS
        ON
            TRANS.STAGE = 'LOCATION_CODE'
            AND TCD.TRANSMODE = TRANS.SOURCE_CODE
    INNER JOIN UDC AS ITM
        ON
            ITM.STAGE = 'ITEM_NAME_ITEM_L1'
            AND TCD.ITEMID = ITM.SOURCE_CODE
    INNER JOIN UDC AS ORIG
        ON
            ORIG.STAGE = 'UNITID_ORIGEM'
            AND TCD.SOURCE = ORIG.SOURCE_CODE
    INNER JOIN UDC AS DEST
        ON
            DEST.STAGE = 'UNITID_DESTINATION'
            AND TCD.DESTINATION = DEST.SOURCE_CODE
),

TCD AS (
    SELECT
        TRANSPORTATIONCONTRACTID,
        TRANSPORTATIONCONTRACTLINEID,
        STARTDATE,
        ENDDATE,
        UOM,
        COMMENTS,
        PAIDPENALTY,
        CURRENCY,
        MINTOLERANCE,
        SOURCE,
        DESTINATION,
        ITEMID,
        PENALTYFEE,
        TRANSMODE,
        LANEID,
        TOPRATE,
        BK_ID,
        BK_LINEID,
        SUM(QUANTITY) AS QUANTITY
    FROM TCD_TRNS
    GROUP BY
        TRANSPORTATIONCONTRACTID,
        TRANSPORTATIONCONTRACTLINEID,
        STARTDATE,
        ENDDATE,
        UOM,
        COMMENTS,
        PAIDPENALTY,
        CURRENCY,
        MINTOLERANCE,
        SOURCE,
        DESTINATION,
        ITEMID,
        PENALTYFEE,
        TRANSMODE,
        LANEID,
        TOPRATE,
        BK_ID,
        BK_LINEID
),

TRANSPORTATION_CONTRACT_DETAILS AS (
    SELECT DISTINCT
        BK_ID,
        BK_LINEID,
        NULL AS TRANSPORTATIONCONTRACTID,
        NULL AS TRANSPORTATIONCONTRACTLINEID,
        COALESCE(MINTOLERANCE, 0) AS MINTOLERANCE,
        NULLIF(COALESCE(SOURCE, 'N/A'), '') AS SOURCE,
        NULLIF(COALESCE(DESTINATION, 'N/A'), '') AS DESTINATION,
        NULLIF(COALESCE(ITEMID, 'N/A'), '') AS ITEMID,
        COALESCE(PENALTYFEE::DECIMAL(20, 3), 0.000) AS PENALTYFEE,
        -- NULLIF(COALESCE(LANEID, 'N/A'), '') AS LANEID,
        NULLIF(COALESCE(TRANSMODE, 'N/A'), '') AS TRANSMODE,
        COALESCE(STARTDATE, 'N/A') AS STARTDATE,
        COALESCE(ENDDATE, 'N/A') AS ENDDATE,
        COALESCE(QUANTITY::DECIMAL(20, 3), 0.00) AS QUANTITY,
        COALESCE(TOPRATE::DECIMAL(20, 3), 0.00) AS TOPRATE,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM,
        COALESCE(NULLIF(COMMENTS, ''), 'N/A') AS COMMENTS,
        COALESCE(PAIDPENALTY::DECIMAL(20, 3), 0.00) AS PAIDPENALTY,
        COALESCE(NULLIF(CURRENCY, ''), 'N/A') AS CURRENCY
    FROM TCD
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM TRANSPORTATION_CONTRACT_DETAILS
WHERE
    1 = 1
    AND {{ date_max_filter('STARTDATE','DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('ENDDATE','DD-MM-YYYY', 'na') }}
