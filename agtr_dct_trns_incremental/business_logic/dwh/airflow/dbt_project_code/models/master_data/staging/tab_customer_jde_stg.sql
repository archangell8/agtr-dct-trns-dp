-- noqa: disable=all
{{
    config(
        materialized='table'
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

CREDITBLOCKED AS (
    /* CHECK CUSTOMERS QUE TEM DADO DIFERENTE DE '' NAS TABELAS F411 E F4201 */
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY SDAN8
            ORDER BY CREDITBLOCKED ASC
        ) AS RK
    FROM (
        SELECT DISTINCT
            F4211.SDAN8,
            CASE
                WHEN
                    TRIM(F4211.SDDTYS) != ''
                    OR
                    TRIM(F4201.SHHOLD) != ''
                    THEN FALSE
                ELSE TRUE
            END AS CREDITBLOCKED
        FROM {{ source('jde', 'F4201') }} AS F4201
        LEFT JOIN {{ source('jde', 'F4211') }} AS F4211
            ON
                F4201.SHKCOO = F4211.SDKCOO
                AND F4201.SHMCU = F4211.SDEMCU
                AND F4201.SHDOCO = F4211.SDDOCO
                AND F4201.SHDCTO = F4211.SDDCTO
                AND {{ filter_remove_jde_delete_data('F4211') }}
        WHERE
            1 = 1
            AND {{ filter_remove_jde_delete_data('F4201') }}
    )
),

CUSTOMER_JDE AS (
    SELECT DISTINCT
        F0101.ABAN8 AS CUSTOMERID,
        COALESCE(F0150.MAPA8, F0101.ABAN8) AS PARENTID,
        TRIM(F0101.ABTAX) AS TAXID,
        COALESCE(CTE_STATUS.TARGET_CODE, 'ATIVO') AS "STATUS",
        COALESCE(CUST_TYPE.TARGET_CODE, 'N/A') AS "TYPE",
        TRIM(F0101.ABALPH) AS "NAME",
        TRIM(REPLACE(F0116.ALADD1, ';', '')) AS "ADDRESS",
        TRIM(F0116.ALADD2) AS COMPLEMENT,
        TRIM(F0116.ALADD3) AS NEIGHBORHOOD,
        TRIM(F0116.ALADDZ) AS ZIPCODE,
        COALESCE(
            TRIM(SUBSTR(IBGE_CODE.DRDL01, 1, LENGTH(IBGE_CODE.DRDL01) - 4)), --noqa
            TRIM(F0116.ALCTY1) --noqa
        ) AS CITY,
        TRIM(F0116.ALADDS) AS "STATE",
        TRIM(F0116.ALCTR) AS COUNTRY,
        TRIM(F0116.ALCOUN) AS IBGE,
        COALESCE(CB.CREDITBLOCKED, FALSE) AS CREDITBLOCKED
    FROM {{ source('jde', 'F0101') }} AS F0101
    LEFT JOIN CTE_UDC_MAPPING AS CUST_TYPE
        ON
            UPPER(TRIM(F0101.ABAT1)) = CUST_TYPE.SOURCE_CODE
            AND CUST_TYPE.CATEGORY = 'CUSTOMER_JDE_TYPE'
            AND CUST_TYPE.STAGE = 'CUSTOMER'
    LEFT JOIN CTE_UDC_MAPPING AS CTE_STATUS
        ON
            UPPER(TRIM(F0101.ABMCU)) = CTE_STATUS.SOURCE_CODE
            AND CTE_STATUS.CATEGORY = 'CUSTOMER_JDE_ACTIVE'
            AND CTE_STATUS.STAGE = 'CUSTOMER'
    LEFT JOIN {{ source('jde', 'F0150') }} AS F0150
        ON
            F0101.ABAN8 = F0150.MAAN8
            AND {{ filter_remove_jde_delete_data('F0150') }}
    LEFT JOIN (
        SELECT
            *,
            ROW_NUMBER() OVER (PARTITION BY ALAN8 ORDER BY ALUPMJ DESC) AS RN
        FROM {{ source('jde', 'F0116') }}
        WHERE {{ filter_remove_jde_delete_data('F0116') }}
        QUALIFY RN = 1
    ) AS F0116
        ON
            TRIM(F0101.ABAN8) = TRIM(F0116.ALAN8)
    LEFT JOIN {{ source('jde','PRODCTL_F0005') }} AS IBGE_CODE
        ON
            IBGE_CODE.DRSY = '5504'
            AND IBGE_CODE.DRRT = 'MU'
            AND TRIM(IBGE_CODE.DRKY) = REPLACE(
                REPLACE(REPLACE(
                    TRIM(F0116.ALCOUN), CHR(9), ' '
                ), CHR(10), ''), CHR(13), ''
            )
    LEFT JOIN CREDITBLOCKED AS CB
        ON CB.SDAN8 = F0101.ABAN8
        AND CB.RK = 1
    WHERE
        1 = 1
        AND F0101.ABAN8 BETWEEN 37000000 AND 37999999
        AND F0101.ABAT1 IN ('B', 'C', 'V')
        AND {{ filter_remove_jde_delete_data('F0101') }}
)

SELECT
    CUSTOMERID,
    CREDITBLOCKED,
    PARENTID,
    TAXID,
    STATUS AS "STATUS",
    TYPE AS "TYPE",
    NAME AS "NAME",
    ADDRESS AS "ADDRESS",
    COMPLEMENT,
    NEIGHBORHOOD,
    ZIPCODE,
    CITY,
    STATE AS "STATE",
    COUNTRY,
    IBGE
FROM CUSTOMER_JDE
