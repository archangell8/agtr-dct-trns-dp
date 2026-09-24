-- noqa: disable=all
{{
    config(
        materialized='view'
    )
}}

WITH
PRODCTL_F0005 AS (
    SELECT
        DRDL01,
        DRKY,
        DRSY,
        DRRT
    FROM {{ source('jde', 'PRODCTL_F0005') }}
    WHERE
        TRIM(DRSY) = '00'
        AND {{ filter_remove_jde_delete_data('PRODCTL_F0005') }}
),

F92 AS (
    SELECT
        T3RMK,
        T3RMK2
    FROM {{ source('jde', 'F00092') }}
    WHERE
        TRIM(T3SDB) = 'REAG'
        AND TRIM(T3TYDT) = '07'
        AND {{ filter_remove_jde_delete_data('F00092') }}
),

UDC AS (
    SELECT
        CATEGORY,
        STAGE,
        SOURCE_CODE,
        TARGET_CODE
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
    WHERE
        1 = 1
        AND STATUS = 'ATIVO'
),

MAIN_TEMP AS (
    SELECT
        CASE
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 3
                AND TRIM(NULLIF(BP.MCRP36, ''))::INT >= 1
            )
                THEN TRIM(BP.MCAN8GCA1)
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 1
                AND TRIM(NULLIF(BP.MCRP24, ''))::INT = 3
                AND BP.MCAN8GCA3 != 0
            )
                THEN TRIM(BP.MCAN8GCA3)
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 1
                AND TRIM(NULLIF(BP.MCRP24, ''))::INT = 3
                AND BP.MCAN8GCA1 != 0
            )
                THEN TRIM(BP.MCAN8GCA1)
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 1
                AND TRIM(NULLIF(BP.MCRP24, ''))::INT = 3
                AND BP.MCAN8GCA2 != 0
            )
                THEN TRIM(BP.MCAN8GCA2)
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 1
                AND TRIM(NULLIF(BP.MCRP24, ''))::INT = 4
                AND TRIM(NULLIF(BP.MCRP10, '')) = 'TBO'
                AND BP.MCAN8GCA2 != 0
            )
                THEN TRIM(BP.MCAN8GCA2)
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 2
                AND TRIM(NULLIF(BP.MCRP24, ''))::INT = 99
                AND BP.MCAN8GCA1 != 0
            )
                THEN TRIM(BP.MCAN8GCA1)
            WHEN (
                TRIM(NULLIF(BP.MCRP35, ''))::INT = 4
                AND BP.MCAN8GCA1 != 0
            )
               THEN TRIM(BP.MCAN8GCA1)
            WHEN (
               TRIM(NULLIF(BP.MCRP35, ''))::INT = 2
               AND TRIM(NULLIF(BP.MCRP24, ''))::INT = 99
               AND BP.MCAN8GCA3 != 0
            )
               THEN TRIM(BP.MCAN8GCA3)
            ELSE TRIM(BP.MCAN8)
        END AS ADDRESS_BOOK,
        TRIM(BP.MCMCU) AS BP_NUMBER,
        UPPER(TRIM(BP.MCDL01)) AS BP_NAME,
        COALESCE(TRIM(NULLIF(
            DECODE(ORIGIN_UNIT.BPZ55REA02, 'GJA', 'SP', ORIGIN_UNIT.BPZ55REA02),
            ''
        )), UNIT.SUB_REGION, 'N/A') AS ORIGIN_SUBREGION,
        COALESCE(
            UNIT.UNIT_NOME, TRIM(ORIGIN_UNIT.BPDL01), 'N/A'
        ) AS ORIGIN_UNIT_NAME,
        COALESCE(
            UNIT.UNIT_BASE, TRIM(ORIGIN_UNIT.BPZ55REUNI), 'N/A'
        ) AS ORIGIN_UNIT_ID,
        CASE
            WHEN TRIM(BP.MCMCU) LIKE '02191100%'
                THEN 'FABRICA UBERLANDIA'
            WHEN TRIM(BP.MCMCU) LIKE '02191570%'
                THEN 'CARGILL AGRICOLA - AMIDOS CASTRO'
            WHEN HASH(TRIM(F0005_35.DRDL01)) = -7540469061666017474 --WHEN TRIM(F0005_35.DRDL01) = 'FÍSICA' THEN
                OR TRIM(F0005_35.DRDL01) = 'TROCA DE NOTA FISCAL'
                THEN COALESCE(UNIT.UNIT_NOME, TRIM(ORIGIN_UNIT.BPDL01), 'N/A')
            ELSE COALESCE(TRIM(DESTINATION_UNIT.BPDL01), 'N/A')
        END AS DESTINATION_UNIT_NAME,
        CASE
            WHEN TRIM(BP.MCMCU) LIKE '02191100%'
                THEN '837'
            WHEN TRIM(BP.MCMCU) LIKE '02191570%'
                THEN '867'
            WHEN HASH(TRIM(F0005_35.DRDL01)) = -7540469061666017474 --WHEN TRIM(f0005_35.drdl01) = 'FÍSICA' --noqa
                OR TRIM(F0005_35.DRDL01) = 'TROCA DE NOTA FISCAL'
                THEN COALESCE(UNIT.UNIT_BASE, TRIM(ORIGIN_UNIT.BPZ55REUNI), 'N/A')
            ELSE COALESCE(TRIM(BP.MCRP36), 'N/A')
        END AS DESTINATION_UNIT_ID,
        CASE
            WHEN TRIM(BP.MCMCU) LIKE '02191100%'
                THEN '3170206'
            WHEN TRIM(BP.MCMCU) LIKE '02191570%'
                THEN '4104907'
            WHEN HASH(TRIM(F0005_35.DRDL01)) = -7540469061666017474 --WHEN TRIM(F0005_35.DRDL01) = 'FÍSICA' --noqa
                OR TRIM(F0005_35.DRDL01) = 'TROCA DE NOTA FISCAL'
                THEN COALESCE(TRIM(ORIGIN_UNIT.BPZ55REA07), 'N/A')
            ELSE COALESCE(TRIM(DESTINATION_UNIT.BPZ55REA07), 'N/A')
        END AS DESTINATION_IBGE_ID,
        CASE
            WHEN TRIM(BP.MCRP09) = 'INA'
                THEN 'INATIVA'
            ELSE 'ATIVA'
        END AS "STATUS",
        COALESCE(
            UDC_EXPENSE.TARGET_CODE, TRIM(BP.MCRP02)
        ) AS ORIGIN_FILIAL_EXPENSE
    FROM {{ source('jde', 'F0006') }} AS BP
    LEFT JOIN {{ source('pscfl', 'F_MIN_LOCATION_UNIT') }} AS UNIT
        ON
            TRIM(BP.MCMCU) = TRIM(UNIT.BP_COD)
    LEFT JOIN PRODCTL_F0005 AS F0005_35
        ON
            TRIM(F0005_35.DRKY) = TRIM(BP.MCRP35)
            AND F0005_35.DRRT = '35'
    LEFT JOIN PRODCTL_F0005 AS F0005_37
        ON
            TRIM(F0005_37.DRKY) = TRIM(BP.MCRP37)
            AND F0005_37.DRRT = '37'
    LEFT JOIN PRODCTL_F0005 AS F0005_17
        ON
            TRIM(F0005_17.DRKY) = TRIM(BP.MCRP17)
            AND F0005_17.DRRT = '17'
    LEFT JOIN {{ source('jde', 'F554006') }} AS ORIGIN_UNIT
        ON
            TRIM(ORIGIN_UNIT.BPZ55REUNI) = TRIM(BP.MCRP34)
            AND {{ filter_remove_jde_delete_data('ORIGIN_UNIT') }}
    LEFT JOIN {{ source('jde', 'F554006') }} AS DESTINATION_UNIT
        ON
            TRIM(DESTINATION_UNIT.BPZ55REUNI) = TRIM(BP.MCRP36)
            AND {{ filter_remove_jde_delete_data('DESTINATION_UNIT') }}
    LEFT JOIN F92 AS ORIGIN_PLACE
        ON
            TRIM(ORIGIN_PLACE.T3RMK) = TRIM(ORIGIN_UNIT.BPZ55REA07)
    LEFT JOIN F92 AS DESTINATION_PLACE
        ON
            TRIM(DESTINATION_PLACE.T3RMK) = TRIM(DESTINATION_UNIT.BPZ55REA07)
    LEFT JOIN UDC AS UDC_EXPENSE
        ON
            UDC_EXPENSE.CATEGORY='LOCATION_BP'
            AND UDC_EXPENSE.STAGE='ORIGIN_FILIAL_EXPENSE'
            AND TRIM(UDC_EXPENSE.SOURCE_CODE) = TRIM(BP.MCRP02)
    LEFT JOIN UDC AS UDC_EXCLUSION
        ON
            TRIM(BP.MCMCU) = TRIM(UDC_EXCLUSION.SOURCE_CODE)
            AND UDC_EXCLUSION.CATEGORY ='LOCATION_BP'
            AND UDC_EXCLUSION.STAGE='BP_EXCLUIR'
    WHERE
        1 = 1
        AND (BP.MCSTYL = 'BP' OR TRIM(BP.MCRP21) = '5026')
        AND TRIM(BP.MCCO) IN (
            '52171',
            '52191',
            '52180'
            -- '52194',
            -- '52244',
            -- '52320',
            -- '52220',
        )
        AND
        (
            TRIM(BP.MCMCU) LIKE '02171_____'
            OR TRIM(BP.MCMCU) LIKE '02191___%'
            OR TRIM(BP.MCMCU) LIKE '02180_____'
            -- OR TRIM(BP.MCMCU) LIKE '02244___%'
            -- OR TRIM(BP.MCMCU) LIKE '02194___%'
            -- OR TRIM(BP.MCMCU) LIKE '02220___%'
        )
        -- excluir BPs que não devem ser enviadas
        AND UDC_EXCLUSION.SOURCE_CODE IS NULL
        AND {{ filter_remove_jde_delete_data('BP') }}
),

UDC_TEMP AS (
    SELECT
        U.TARGET_CODE AS BP_NUMBER,
        LT.LOCATION_NAME AS BP_NAME,
        LS.LOCATION_SUB_REGION AS ORIGIN_SUBREGION,
        LS.LOCATION_NAME AS ORIGIN_UNIT_NAME,
        LS.LOCATION_UNIT_ID AS ORIGIN_UNIT_ID,
        LS.LOCATION_NAME AS DESTINATION_UNIT_NAME,
        LS.LOCATION_UNIT_ID AS DESTINATION_UNIT_ID,
        LS.IBGE AS DESTINATION_IBGE_ID,
        U.TARGET_CODE AS ADDRESS_BOOK,
        LS.LOCATION_CODE,
        LS.LOCATION_TYPE,
        'ATIVA' AS "STATUS",
        SUBSTR(LS.LOCATIONID, 5, 3) AS ORIGIN_FILIAL_EXPENSE
    FROM UDC AS U
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LS
        ON U.SOURCE_CODE = LS.LOCATION_UNIT_ID
    INNER JOIN {{ ref('location_master') }} AS LT
        ON U.TARGET_CODE = LT.LOCATIONID
    WHERE
        U.CATEGORY ='LOCATION_BP'
        AND U.STAGE='LOCAL_COLETA'
),

MAIN AS (
    SELECT
        BP_NUMBER,
        BP_NAME,
        ORIGIN_SUBREGION,
        ORIGIN_UNIT_NAME,
        ORIGIN_UNIT_ID,
        DESTINATION_UNIT_NAME,
        DESTINATION_UNIT_ID,
        DESTINATION_IBGE_ID,
        ADDRESS_BOOK,
        COALESCE(
            NULLIF(B.LOCATION_CODE, ''),
            NULLIF(A.ORIGIN_SUBREGION, '')
        ) AS LOCATION_CODE,
        B.LOCATION_TYPE,
        STATUS,
        ORIGIN_FILIAL_EXPENSE
    FROM MAIN_TEMP AS A
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS B
        ON TRIM(B.LOCATIONID) = TRIM(A.BP_NUMBER)

    UNION

    SELECT
        BP_NUMBER,
        BP_NAME,
        ORIGIN_SUBREGION,
        ORIGIN_UNIT_NAME,
        ORIGIN_UNIT_ID,
        DESTINATION_UNIT_NAME,
        DESTINATION_UNIT_ID,
        DESTINATION_IBGE_ID,
        ADDRESS_BOOK,
        LOCATION_CODE,
        LOCATION_TYPE,
        STATUS,
        ORIGIN_FILIAL_EXPENSE
    FROM UDC_TEMP
)

SELECT DISTINCT
    COALESCE(NULLIF(A.BP_NUMBER, ''), 'N/A') AS BP_NUMBER,
    COALESCE(NULLIF(A.BP_NAME, ''), 'N/A') AS BP_NAME,
    COALESCE(NULLIF(A.ORIGIN_SUBREGION, ''), 'N/A') AS ORIGIN_SUBREGION,
    COALESCE(NULLIF(A.ORIGIN_UNIT_NAME, ''), 'N/A') AS ORIGIN_UNIT_NAME,
    COALESCE(NULLIF(A.ORIGIN_UNIT_ID, ''), 'N/A') AS ORIGIN_UNIT_ID,
    COALESCE(NULLIF(A.DESTINATION_UNIT_NAME, ''), 'N/A')
        AS DESTINATION_UNIT_NAME,
    COALESCE(NULLIF(A.DESTINATION_UNIT_ID, ''), 'N/A') AS DESTINATION_UNIT_ID,
    COALESCE(NULLIF(A.DESTINATION_IBGE_ID, ''), 'N/A') AS DESTINATION_IBGE_ID,
    COALESCE(NULLIF(A.ADDRESS_BOOK, ''), 'N/A') AS ADDRESS_BOOK,
    COALESCE(NULLIF(A.LOCATION_CODE, ''), 'N/A') AS LOCATION_CODE,
    COALESCE(NULLIF(A.LOCATION_TYPE, ''), 'N/A') AS LOCATION_TYPE,
    COALESCE(NULLIF(A.STATUS, ''), 'N/A') AS STATUS,
    COALESCE(NULLIF(A.ORIGIN_FILIAL_EXPENSE, ''), 'N/A')
        AS ORIGIN_FILIAL_EXPENSE,
    HASH(*) AS HASH_ID
FROM MAIN AS A

