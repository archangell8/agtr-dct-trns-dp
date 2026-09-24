-- noqa: disable=ST09
{{
    config(
        materialized='view'
    )
}}

WITH
CONVERSION_TO_KG AS (
    SELECT
        TRIM(B.IMLITM) AS ITEM,
        TRIM(A.UMUM) AS UOMFROM,
        TRIM(A.UMRUM) AS UOMTO,
        A.UMCONV::DOUBLE / 10000000 AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F41002') }} AS A
    INNER JOIN {{ source('jde', 'F4101') }} AS B
        ON
            A.UMITM = B.IMITM
            AND A.UMUM = (CASE
                WHEN TRIM(B.IMLITM) = '98577' AND TRIM(B.IMUOM1) = 'PK'
                    THEN 'CX'
                ELSE B.IMUOM1
            END)
    WHERE
        1 = 1
        AND A.UMRUM = 'KG'
),

ALL_TO_KGS_DIRETO AS (
    SELECT
        TRIM(B.IMLITM) AS ITEM,
        TRIM('KG') AS UOMFROM,
        TRIM(A.UMRUM) AS UOMTO,
        CASE
            WHEN A.UMRUM = 'KG' THEN 1
            ELSE ROUND(
                (
                    COALESCE(1 / C.SUPPLYPLANNINGFINALCONVERSIONFACTOR, 1)
                ) * A.UMCONV::DOUBLE / 10000000,
                6
            )
        END AS FACTOR,
        TRIM(A.UMUM) AS UMUM,
        TRIM(A.UMRUM) AS UMRUM,
        A.UMCONV::DOUBLE / 10000000 AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F41002') }} AS A
    INNER JOIN {{ source('jde', 'F4101') }} AS B
        ON
            A.UMITM = B.IMITM
            AND A.UMUM = (CASE
                WHEN TRIM(B.IMLITM) = '98577' AND TRIM(B.IMUOM1) = 'PK'
                    THEN 'CX'
                ELSE B.IMUOM1
            END)
    LEFT JOIN CONVERSION_TO_KG AS C ON TRIM(C.ITEM) = TRIM(B.IMLITM)
),

ALL_TO_KGS_INVERSO AS (
    SELECT
        TRIM(B.IMLITM) AS ITEM,
        TRIM('KG') AS UOMFROM,
        TRIM(A.UMUM) AS UOMTO,
        CASE
            WHEN A.UMUM = 'KG' THEN 1
            ELSE (
                COALESCE(C.SUPPLYPLANNINGFINALCONVERSIONFACTOR, 1)
            ) * 1 / (A.UMCONV::DOUBLE / 10000000)
        END AS FACTOR,
        TRIM(A.UMUM) AS UMUM,
        TRIM(A.UMRUM) AS UMRUM,
        1 / (A.UMCONV::DOUBLE / 10000000) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F41002') }} AS A
    INNER JOIN {{ source('jde', 'F4101') }} AS B
        ON
            A.UMITM = B.IMITM
            AND A.UMRUM = (CASE
                WHEN TRIM(B.IMLITM) = '98577' AND TRIM(B.IMUOM1) = 'PK'
                    THEN 'CX'
                ELSE B.IMUOM1
            END)
    LEFT JOIN CONVERSION_TO_KG AS C ON TRIM(C.ITEM) = TRIM(B.IMLITM)
    WHERE TRIM(B.IMLITM) != '98576'
),

ALL_TO_TN_DIRETO AS (
    SELECT
        ITEM,
        'TN' AS UOMFROM,
        UOMTO,
        ROUND(FACTOR * 1000, 3) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM ALL_TO_KGS_DIRETO
),

ALL_TO_TN_INVERSO AS (
    SELECT
        ITEM,
        'TN' AS UOMFROM,
        UOMTO,
        ROUND(FACTOR * 1000, 3) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM ALL_TO_KGS_INVERSO
),

TN_TO_KGS AS (
    SELECT
        TRIM(B.IMLITM) AS ITEM,
        TRIM(A.UMRUM) AS UOMFROM,
        TRIM(A.UMUM) AS UOMTO,
        ROUND(
            1 / (A.UMCONV::DOUBLE / 10000000),
            3
        ) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F41002') }} AS A
    INNER JOIN {{ source('jde', 'F4101') }} AS B
        ON
            A.UMITM = B.IMITM
            AND A.UMUM = B.IMUOM1
    WHERE
        1 = 1
        AND A.UMUM = 'KG'
        AND A.UMRUM = 'TN'

    UNION DISTINCT

    SELECT
        TRIM(B.IMLITM) AS ITEM,
        TRIM(A.UMUM) AS UOMFROM,
        TRIM('KG') AS UOMTO,
        CASE
            WHEN A.UMUM = 'KG' THEN 1
            ELSE COALESCE(
                C.SUPPLYPLANNINGFINALCONVERSIONFACTOR,
                1
            ) * (A.UMCONV / 10000000)
        END AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F41002') }} AS A
    INNER JOIN {{ source('jde', 'F4101') }} AS B
        ON
            A.UMITM = B.IMITM
            AND A.UMRUM = B.IMUOM1
    LEFT JOIN CONVERSION_TO_KG AS C ON TRIM(C.ITEM) = TRIM(B.IMLITM)
    WHERE
        1 = 1
        AND A.UMUM = 'TN'
),

TN_TO_UOM AS (
    SELECT
        TRIM(B.IMLITM) AS ITEM,
        TRIM('TN') AS UOMFROM,
        TRIM(A.UMUM) AS UOMTO,
        ROUND(
            1 / (A.UMCONV::DOUBLE / 10000000) * 1000,
            3
        ) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F41002') }} AS A
    INNER JOIN {{ source('jde', 'F4101') }} AS B
        ON
            A.UMITM = B.IMITM
            AND A.UMUM = (CASE
                WHEN TRIM(B.IMLITM) = '98577' AND TRIM(B.IMUOM1) = 'PK'
                    THEN 'CX'
                ELSE B.IMUOM1
            END)
    WHERE
        1 = 1
        AND A.UMRUM = 'KG'
),

TN_TO_TN AS (
    SELECT DISTINCT
        TRIM(A.IMLITM) AS ITEM,
        TRIM('TN') AS UOMFROM,
        TRIM('TN') AS UOMTO,
        COALESCE(1, 1) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F4101') }} AS A
    INNER JOIN {{ source('jde', 'F4102') }} AS B ON A.IMITM = B.IBITM
),
--CONVERSÃO DO ITEM 98577

I98577_INIT AS (
    SELECT
        A.IMLITM AS ITEM,
        A.IMITM AS ITM,
        B.UMRUM AS UMFROM,
        B.UMUM AS UOMTO,
        1 / (B.UMCONV / 10000000) AS CONV
    FROM {{ source('jde', 'F4101') }} AS A
    INNER JOIN {{ source('jde', 'F41002') }} AS B
        ON
            A.IMITM = B.UMITM
            AND A.IMUOM1 = B.UMRUM
    WHERE A.IMLITM = '98577'
),

I98577_CONV_KG AS (
    SELECT
        A.IMITM AS ITM,
        A.IMLITM AS ITEM,
        'CX' AS UOMFROM,
        B.UMRUM AS UOMTO,
        ROUND((B.UMCONV / 10000000), 3) AS CONV
    FROM {{ source('jde', 'F4101') }} AS A
    INNER JOIN {{ source('jde', 'F41002') }} AS B ON A.IMITM = B.UMITM
    INNER JOIN I98577_INIT AS C
        ON
            C.ITM = A.IMITM
            AND B.UMUM = C.UOMTO
    WHERE B.UMRUM = 'KG'
),

I98577_ALL_CONV AS (
    SELECT
        A.IMITM AS ITM,
        A.IMLITM AS ITEM,
        'TN' AS UOMFROM,
        B.UMRUM AS UOMTO,
        C.CONV AS CONVKG,
        ROUND(((B.UMCONV / 10000000) / C.CONV) * 1000, 3) AS CONV,
        ROUND((B.UMCONV / 10000000), 3) AS CONVPADRAO
    FROM {{ source('jde', 'F4101') }} AS A
    INNER JOIN {{ source('jde', 'F41002') }} AS B ON A.IMITM = B.UMITM
    INNER JOIN I98577_CONV_KG AS C
        ON
            C.ITEM = A.IMLITM
            AND B.UMUM = C.UOMFROM
),

I98577_FINAL AS (
    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        CONV AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM I98577_ALL_CONV
),

MISS_ITENS AS (
    SELECT DISTINCT
        TRIM(A.IMLITM) AS ITEM,
        TRIM('TN') AS UOMFROM,
        TRIM('KG') AS UOMTO,
        COALESCE(1000, 1000) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('jde', 'F4101') }} AS A
    INNER JOIN {{ source('jde', 'F4102') }} AS B ON A.IMITM = B.IBITM
    WHERE A.IMLITM IN ('285918', '94429')
),

MAIN AS (
    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM ALL_TO_TN_DIRETO AS DIR
    WHERE
        1 = 1
        AND NOT EXISTS (
            SELECT 1
            FROM TN_TO_TN AS TN
            WHERE
                TN.ITEM = DIR.ITEM
                AND TN.UOMFROM = DIR.UOMFROM
                AND TN.UOMTO = DIR.UOMTO
        )

    UNION DISTINCT

    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM ALL_TO_TN_INVERSO

    UNION DISTINCT

    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM TN_TO_KGS

    UNION DISTINCT

    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM TN_TO_TN

    UNION DISTINCT

    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM TN_TO_UOM

    UNION DISTINCT

    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM I98577_FINAL

    UNION DISTINCT

    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM MISS_ITENS
),

ITENS_UDC AS (
    SELECT
        ITM.ITEM,
        UDC.SOURCE_CODE AS UOMFROM,
        UDC.TARGET_CODE AS UOMTO,
        UDC.TARGET_NUMBER::DECIMAL(20, 3) AS SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }} AS UDC
    INNER JOIN {{ ref('item_master') }} AS ITM
        ON TRIM(UDC.STAGE) = TRIM(ITM.L1)
    WHERE
        1 = 1
        AND UDC.CATEGORY = 'UOM_CONVERSION'
        AND UDC.STATUS = 'ATIVO'
        AND UDC.SOURCE_CODE = 'TN'
),

UOM_MASTER AS (
    SELECT DISTINCT
        MA.ITEM,
        MA.UOMFROM,
        MA.UOMTO,
        MA.SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM MAIN AS MA
    LEFT OUTER JOIN ITENS_UDC AS UDC
        ON
            MA.ITEM = UDC.ITEM
            AND MA.UOMFROM = UDC.UOMFROM
            AND MA.UOMTO = UDC.UOMTO
    WHERE
        UDC.ITEM IS NULL

    UNION DISTINCT

    SELECT DISTINCT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR
    FROM ITENS_UDC
)

SELECT
    MAS.*,
    HASH(*) AS HASH_ID
FROM UOM_MASTER AS MAS
INNER JOIN {{ ref('item_master') }} AS IT
    ON IT.ITEM = MAS.ITEM
