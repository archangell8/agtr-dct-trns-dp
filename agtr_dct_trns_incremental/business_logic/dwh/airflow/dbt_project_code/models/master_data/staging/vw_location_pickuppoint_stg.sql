-- noqa: disable=all
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

CTE_LAT_LONG AS (
    SELECT
        T0.CGAN8,
        T0.CGZ55LATI,
        T0.CGZ55LONG
    FROM {{ source('jde','F5549320') }} AS T0
    WHERE
        T0.CGSTA = 'A' --Ativo
        AND T0.CGAPPST = 'A' --Aprovado
        AND {{ filter_remove_jde_delete_data('T0') }} -- noqa
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY T0.CGAN8 ORDER BY T0.CGUPMJ DESC
    ) = 1
),

CTE_F0116 AS (
    SELECT *
    FROM {{ source('jde','F0116') }}
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY ALAN8 ORDER BY LENGTH(TRIM(ALADDZ)) DESC, ALUPMJ
    ) = 1
),

LOCATION_PICKUP AS (
    SELECT DISTINCT
        T5.ABTAX AS CNPJ,
        T5.ABTX2 AS IE,
        'CASC SA' AS LOCATION_GROUP,
        TRIM(T2.ALCTR) AS LOCATION_COUNTRY,
        '' AS COMMENTS,
        COALESCE(
            TRIM(SUBSTR(IBGE_CODE.DRDL01, 1, LENGTH(IBGE_CODE.DRDL01) - 4)),
            TRIM(T2.ALCTY1)
        ) AS CITY,
        (TRY_CAST(T0.CGZ55LATI AS BIGINT) / 1000000)::DECIMAL(20, 7) AS LATITUDE,
        (TRY_CAST(T0.CGZ55LONG AS BIGINT) / 1000000)::DECIMAL(20, 7) AS LONGITUDE,
        T2.ALADDS AS "STATE",
        TO_CHAR(T5.ABAN8) AS LOCATIONID,
        TO_CHAR(T5.ABAN8) AS LOCATION_UNIT_ID,
        TO_CHAR(T5.ABAN8) AS ADDRESS_NUMBER,
        TRIM(COALESCE(T7.MAPA8, T5.ABAN8)) AS ADDRESS_PAI,
        NULL AS LOCATION_IBP_ASSET,
        NULL AS LOCATION_SUB_REGION,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(TRIM(T5.ABALPH), '"', ''), CHR(9), ' '
                    ), CHR(10), ''
                ), CHR(13), ''
            ), ';', ''
        ) AS LOCATION_NAME,
        REPLACE(REPLACE(T2.ALADDZ, '"', ''), CHR(9), ' ') AS ZIP,
        REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(CONCAT(
                TRIM(T2.ALADD1), CASE
                    WHEN TRIM(T2.ALADD2) IS NOT NULL
                        THEN CONCAT(' - ', CASE
                            WHEN TRIM(T2.ALADD3) IS NOT NULL
                                THEN CONCAT(
                                    TRIM(T2.ALADD2), CASE
                                        WHEN TRIM(T2.ALADD4) IS NOT NULL
                                            THEN CONCAT(
                                                ' - ', CONCAT(
                                                    TRIM(T2.ALADD3), CONCAT(
                                                        ' - ', TRIM(T2.ALADD4)
                                                    )
                                                )
                                            )
                                        ELSE CONCAT(' - ', TRIM(T2.ALADD3))
                                    END
                                )
                            ELSE CONCAT(TRIM(T2.ALADD2), CASE
                                WHEN TRIM(T2.ALADD4) IS NOT NULL
                                    THEN CONCAT(' - ', TRIM(T2.ALADD4))
                                ELSE ''
                            END)
                        END)
                    WHEN TRIM(T2.ALADD2) IS NULL
                        THEN CASE
                            WHEN TRIM(T2.ALADD3) IS NOT NULL
                                THEN CONCAT(' - ', CASE
                                    WHEN TRIM(T2.ALADD4) IS NOT NULL
                                        THEN CONCAT(
                                            TRIM(T2.ALADD3), CONCAT(
                                                ' - ', TRIM(T2.ALADD4)
                                            )
                                        )
                                    ELSE TRIM(T2.ALADD3)
                                END)
                        END
                END
            ), '"', ''), CHR(9), ' '), CHR(10), ''), CHR(13), ''), ';', ''
        ) AS "ADDRESS",
        TRIM(IBGE_CODE.DRDL02) AS IBGE,
        COALESCE(STRUCTURE.TARGET_CODE, 'CLIENTE OUTBOUND')
            AS LOCATION_UNIT_STRUCTURE,
        COALESCE(REGIAO.TARGET_CODE, 'N/A') AS LOCATION_REGION,
        COALESCE(LOC_TYPE.TARGET_CODE, 'N/A') AS LOCATION_TYPE,
        COALESCE(STATUS.TARGET_CODE, 'TRUE') AS ISACTIVE,
        COALESCE(OWN.TARGET_CODE, 'N/A') AS LOCATION_OWNERSHIP,
        CASE -- noqa
            WHEN COALESCE(T5.ABURDT, 0) = 0 THEN NULL -- noqa
            ELSE TO_CHAR(
                {{ julian_date_to_gregorian('T5', 'ABURDT') }}, 'DD-MM-YYYY' --noqa
            )
        END AS USER_RESERVED_DATE,
        CASE
            WHEN COALESCE(T5.ABUPMJ, 0) = 0
                THEN NULL
            ELSE
                TO_CHAR(
                    {{ julian_date_to_gregorian('T5', 'ABUPMJ') }}, 'DD-MM-YYYY'--noqa
                )
        END AS UPDATED_DATE
    FROM {{ source('jde','F0101') }} AS T5
    INNER JOIN CTE_F0116 AS T2
        ON T5.ABAN8 = T2.ALAN8
    LEFT JOIN {{ source('jde','PRODCTL_F0005') }} AS T1
        ON
            T1.DRSY = '5504'
            AND T1.DRRT = 'CF'
            AND TRIM(T1.DRKY) = REPLACE(
                REPLACE(REPLACE(
                    TRIM(T2.ALCOUN), CHR(9), ' '
                ), CHR(10), ''), CHR(13), ''
            )
            AND {{ filter_remove_jde_delete_data('T1') }} -- noqa
    LEFT JOIN {{ source('jde','PRODCTL_F0005') }} AS IBGE_CODE
        ON
            IBGE_CODE.DRSY = '5504'
            AND IBGE_CODE.DRRT = 'MU'
            AND TRIM(IBGE_CODE.DRKY) = REPLACE(
                REPLACE(REPLACE(
                    TRIM(T2.ALCOUN), CHR(9), ' '
                ), CHR(10), ''), CHR(13), ''
            )
            AND {{ filter_remove_jde_delete_data('IBGE_CODE') }} -- noqa
    LEFT JOIN {{ source('jde','F0006') }} AS T4
        ON
            T2.ALAN8 = T4.MCAN8
            AND LENGTH(TRIM(T4.MCMCU)) = 10
            AND SUBSTR(TRIM(T4.MCMCU), 9, 2) = '00'
            AND {{ filter_remove_jde_delete_data('T4') }} -- noqa
    LEFT JOIN {{ source('jde','F554006') }} AS T6
        ON
            TRIM(T6.BPZ55REUNI) = TRIM(T4.MCRP34)
            AND {{ filter_remove_jde_delete_data('T6') }} -- noqa
    LEFT JOIN {{ source('jde','F0150') }} AS T7
        ON
            TRIM(T5.ABAN8) = TRIM(T7.MAAN8)
            AND TRIM(T7.MAPA8) != '0'
            AND {{ filter_remove_jde_delete_data('T7') }} -- noqa
    LEFT JOIN CTE_LAT_LONG AS T0
        ON
            T2.ALAN8 = T0.CGAN8
    LEFT JOIN CTE_UDC_MAPPING AS STRUCTURE
        ON
            UPPER(TRIM(T5.ABSIC)) = STRUCTURE.SOURCE_CODE
            AND STRUCTURE.CATEGORY = 'LOCATION_PICKUPPOINT_STRUCTURE'
            AND STRUCTURE.STAGE = 'LOCATION'
    LEFT JOIN CTE_UDC_MAPPING AS REGIAO
        ON
            UPPER(TRIM(T2.ALADDS)) = REGIAO.SOURCE_CODE
            AND REGIAO.CATEGORY = 'LOCATION_PICKUPPOINT_REGION'
            AND REGIAO.STAGE = 'LOCATION'
    LEFT JOIN CTE_UDC_MAPPING AS LOC_TYPE
        ON
            UPPER(TRIM(T5.ABAT1)) = LOC_TYPE.SOURCE_CODE
            AND LOC_TYPE.CATEGORY = 'LOCATION_PICKUPPOINT_TIPO'
            AND LOC_TYPE.STAGE = 'LOCATION'
    LEFT JOIN CTE_UDC_MAPPING AS STATUS
        ON
            UPPER(TRIM(T5.ABMCU)) = STATUS.SOURCE_CODE
            AND STATUS.CATEGORY = 'LOCATION_PICKUPPOINT_ACTIVE'
            AND STATUS.STAGE = 'LOCATION'
    LEFT JOIN CTE_UDC_MAPPING AS OWN
        ON
            UPPER(TRIM(T5.ABAT1)) = OWN.SOURCE_CODE
            AND OWN.CATEGORY = 'LOCATION_PICKUPPOINT_OWNERSHIP'
            AND OWN.STAGE = 'LOCATION'
    WHERE
        T5.ABAN8 BETWEEN 37000000 AND 37999999
        AND {{ filter_remove_jde_delete_data('T5') }} -- noqa
        AND {{ filter_remove_jde_delete_data('T2') }} -- noqa
)

SELECT * FROM LOCATION_PICKUP
