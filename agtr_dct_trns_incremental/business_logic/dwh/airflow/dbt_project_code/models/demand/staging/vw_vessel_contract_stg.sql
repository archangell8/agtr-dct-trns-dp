-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH
CTE_UDC_MAPPING AS (
    SELECT
        CATEGORY,
        STAGE,
        SOURCE_CODE,
        TARGET_CODE,
        TARGET_NUMBER
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
    WHERE
        1 = 1
        AND STATUS = 'ATIVO'
),

FTS_OVER_RAW AS (
    SELECT -- noqa
        QT_PRODUCT,
        QT_NOMINATION,
        QT_OU,
        CD_JDE_PRODUCT,
        TO_CHAR(
            --COALESCE(DT_BL, DT_FROM_LAYCAN, DT_SHIPMENT_FROM), 'DD-MM-YYYY'
            COALESCE(DT_BL, DT_SLATE_PERIOD), 'DD-MM-YYYY'
        ) AS "DATE",
        DS_CAK_NBR,
        DS_NOMINATION,
        DT_LEVEL,
        CD_NICK_LOAD_PLACE,
        CD_NICK_PRODUCT,
        CD_NICK_SELLER,
        DS_CAK_TYPE,
        DS_VESSEL,
        DS_CAK_STATE
    FROM {{ source('fts', 'CAK_OVER_UNDER') }}
    WHERE
        1 = 1
        AND LEFT(TRIM(DS_CAK_NBR), 3) IN ('CCP', 'CCS', 'TCS', 'TCP')
        AND DT_SLATE_PERIOD >= TO_DATE('2025-01-01')
        AND CD_NICK_SELLER != 'BCASA'
        AND CD_NICK_BUYER != 'BCASA'
        AND DS_CAK_STATE != 'DELETED'
        -- AND NOT (
        --     DS_VESSEL IS NULL
        --     AND DT_SHIPMENT_TO < TO_DATE(
        --         TO_CHAR(
        --             DATE_TRUNC('MONTH', CURRENT_DATE), 'DD-MM-YYYY'
        --         ), 'DD-MM-YYYY'
        --     )
        -- )
),

FTS_TEMP AS (
    SELECT DISTINCT -- noqa
        CODE.TARGET_CODE AS PORT,
        OVER_RAW.CD_JDE_PRODUCT AS ITEM,
        'TN' AS UOM,
        CASE
            WHEN OVER_RAW.CD_NICK_SELLER = 'CCT'
                THEN COALESCE(OVER_RAW.QT_PRODUCT * (-1), 0)
            ELSE COALESCE(OVER_RAW.QT_PRODUCT, 0)
        END AS "CONTRACT",

        CASE
            WHEN OVER_RAW.CD_NICK_SELLER = 'CCT'
                THEN COALESCE(OVER_RAW.QT_NOMINATION * (-1), 0)
            ELSE COALESCE(OVER_RAW.QT_NOMINATION, 0)
        END AS "NOMINATION",

        CASE
            WHEN OVER_RAW.CD_NICK_SELLER = 'CCT'
                THEN COALESCE(
                    (OVER_RAW.QT_PRODUCT + (OVER_RAW.QT_OU * (-1))) * (-1), 0
                )
            ELSE COALESCE(OVER_RAW.QT_PRODUCT + (OVER_RAW.QT_OU * (-1)), 0)
        END AS "APPLICATION",
        "DATE", -- noqa
        OVER_RAW.DS_CAK_NBR,
        OVER_RAW.DS_VESSEL
    FROM FTS_OVER_RAW AS OVER_RAW
    INNER JOIN {{ ref('item_master') }} AS IT
        ON TRIM(OVER_RAW.CD_JDE_PRODUCT) = IT.ITEM
    LEFT JOIN CTE_UDC_MAPPING AS CODE
        ON
            TRIM(OVER_RAW.CD_NICK_LOAD_PLACE) = CODE.SOURCE_CODE
            AND CODE.CATEGORY = 'FTS_PORT_ID'
            AND CODE.STAGE = 'CONTRACT'
    WHERE
        1 = 1
        AND (
            TRIM(OVER_RAW.DS_CAK_TYPE) IN ('OTHERS')
            OR (
                OVER_RAW.CD_NICK_LOAD_PLACE = 'PGAEXPC'
                AND TRIM(OVER_RAW.DS_CAK_TYPE) IN (
                    'PAPER HEDGE', 'PAPER TRADING'
                )
            )
        )
        AND LEFT(TRIM(OVER_RAW.DS_CAK_NBR), 3) IN ('CCS', 'CCP')
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY CONCAT(
                OVER_RAW.DS_CAK_NBR, '.', OVER_RAW.DS_NOMINATION
            ) ORDER BY OVER_RAW.DT_LEVEL DESC
        ) = 1
),

FTS_TEMP2 AS (
    SELECT
        PORT,
        ITEM,
        UOM,
        "CONTRACT",
        "NOMINATION",
        "APPLICATION",
        "DATE",
        DS_CAK_NBR,
        DS_VESSEL
    FROM FTS_TEMP
    QUALIFY
        ROW_NUMBER() OVER (
            PARTITION BY DS_CAK_NBR ORDER BY COALESCE(DS_VESSEL, '0') DESC
        ) = 1
),

FTS_TRANS AS (
    SELECT
        ITEM,
        UOM,
        TRIM(PORT) AS "LOCATION",
        TO_DATE("DATE", 'DD-MM-YYYY') AS "MONTH",
        SUM(CONTRACT) AS "CONTRACT",
        SUM(NOMINATION) AS NOMINATION,
        SUM("APPLICATION") AS "APPLICATION"
    FROM FTS_TEMP2
    WHERE 1 = 1
    GROUP BY
        PORT,
        TO_DATE("DATE", 'DD-MM-YYYY'),
        ITEM,
        UOM
),

VESSELCONTRACT_STG AS (
    SELECT
        LOCATION,
        MONTH,
        CONTRACT AS "VALUE",
        ITEM,
        UOM,
        'CONTRACT' AS "TYPE"
    FROM FTS_TRANS

    UNION ALL

    SELECT
        LOCATION,
        MONTH,
        NOMINATION AS "VALUE",
        ITEM,
        UOM,
        'NOMINATION' AS "TYPE"
    FROM FTS_TRANS

    UNION ALL

    SELECT
        LOCATION,
        MONTH,
        "APPLICATION" AS "VALUE",
        ITEM,
        UOM,
        'APPLICATION' AS "TYPE"
    FROM FTS_TRANS
),

VESSELCONTRACT AS (
    SELECT
        TYPE,
        LOCATION,
        ITEM,
        UOM,
        TO_CHAR(MONTH, 'MM-YYYY') AS MONTH,
        SUM(VALUE::DECIMAL(20, 3)) AS "VALUE"
    FROM VESSELCONTRACT_STG
    WHERE
        1 = 1
    GROUP BY
        TYPE,
        LOCATION,
        TO_CHAR(MONTH, 'MM-YYYY'),
        ITEM,
        UOM
),

FINAL AS (
    SELECT
        COALESCE(NULLIF(LOCATION, ''), 'N/A') AS "LOCATION",
        NULLIF(MONTH, '') AS MONTH,
        COALESCE(NULLIF(ITEM, ''), 'N/A') AS ITEM,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM,
        COALESCE(VALUE::DECIMAL(20, 3), 0) AS "VALUE",
        COALESCE(TYPE, 'N/A') AS "TYPE"
    FROM VESSELCONTRACT
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM FINAL
WHERE
    1 = 1
    AND {{ date_max_filter('MONTH', 'MM-YYYY', 'null') }} --noqa
