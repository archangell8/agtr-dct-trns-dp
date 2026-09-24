{{
    config(
        materialized='view'
    )
}}

WITH
DEMDES AS (
    SELECT DISTINCT
        CAK,
        ETC,
        TRANSPORT AS VESSEL_NAME,
        PORTOS AS PORT,
        PRODUCT,
        QUANTITY,
        CONCAT(
            CAK, '|', ROW_NUMBER() OVER (PARTITION BY CAK ORDER BY ETC ASC)
        ) AS MERGE_ID
    FROM {{ source('pscfl', 'F_MIN_DEMDESPACTUAL') }}
    WHERE BL_DATE >= '2025-01-01 00:00:00'::TIMESTAMP
),

PP_WO_DD AS (
    SELECT
        CAK,
        ETC,
        VESSEL_NAME,
        PORT,
        PRODUCT,
        QUANTITY,
        'PP WITHOUT D&D' AS STATUS
    FROM DEMDES
    WHERE
        MERGE_ID NOT IN (
            SELECT DISTINCT VE.MERGE_ID
            FROM {{ ref('vw_vessel_entire_stg') }} AS VE
            WHERE VE.MERGE_ID IS NOT NULL
        )
        AND CAK IS NOT NULL
),

DD_WO_CAK AS (
    SELECT
        CAK,
        ETC,
        VESSEL_NAME,
        PORT,
        PRODUCT,
        QUANTITY,
        'D&D WITHOUT CAK' AS STATUS
    FROM DEMDES
    WHERE CAK IS NULL
)

SELECT
    CAK,
    STATUS,
    TO_CHAR(ETC, 'DD-MM-YYYY') AS ETC,
    UPPER(VESSEL_NAME) AS VESSEL_NAME,
    UPPER(PORT) AS PORT,
    UPPER(PRODUCT) AS PRODUCT,
    COALESCE(
        REPLACE(QUANTITY, ',', '.')::DECIMAL(20, 3),
        0
    ) AS QUANTITY
FROM PP_WO_DD

UNION DISTINCT

SELECT
    CAK,
    STATUS,
    TO_CHAR(ETC, 'DD-MM-YYYY') AS ETC,
    UPPER(VESSEL_NAME) AS VESSEL_NAME,
    UPPER(PORT) AS PORT,
    UPPER(PRODUCT) AS PRODUCT,
    COALESCE(
        REPLACE(QUANTITY, ',', '.')::DECIMAL(20, 3),
        0
    ) AS QUANTITY
FROM DD_WO_CAK
ORDER BY STATUS ASC
