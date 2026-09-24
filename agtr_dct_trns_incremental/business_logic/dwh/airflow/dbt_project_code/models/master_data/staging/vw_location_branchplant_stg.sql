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

PRODCTL_F0005 AS (
    SELECT
        DRDL01,
        DRDL02,
        DRKY,
        DRSY,
        DRRT
    FROM {{ source('jde', 'PRODCTL_F0005') }}
    WHERE {{ filter_remove_jde_delete_data('PRODCTL_F0005') }} --noqa
),

LOCATION_BP AS (
    SELECT DISTINCT
        TRIM(BP.MCMCU) AS LOCATIONID,
        CASE
            WHEN (TRIM(BP.MCRP35) = '3' AND TRIM(BP.MCRP36) >= '1')
                THEN TRIM(BP.MCRP36)
            ELSE TRIM(BP.MCRP34)
        END AS LOCATION_UNIT_ID,
        TRIM(UNIT.BPZ55REA04) AS LOCATION_UNIT_STRUCTURE,
        'CASC SA' AS LOCATION_GROUP,
        'BR' AS LOCATION_COUNTRY,
        COALESCE(REGIAO.TARGET_CODE, TRIM(UNIT.BPZ55REA01)) AS LOCATION_REGION,
        TRIM(UNIT.BPZ55REA02) AS LOCATION_SUB_REGION,
        TRIM(UNIT.BPDL01) AS LOCATION_NAME,
        COALESCE(TRIM(LOC_TP.DRDL01), 'N/A') AS LOCATION_TYPE,
        NULL AS ZIP,
        NULL AS "ADDRESS",
        NULL AS COMMENTS,
        CASE
            WHEN TRIM(BP.MCRP09) LIKE ('INA')
                THEN 'FALSE'
            WHEN TRIM(BP.MCRP09) IS NULL
                THEN 'FALSE'
            ELSE 'TRUE'
        END AS ISACTIVE,
        UPPER(
            SUBSTR(TRIM(IBGE.T3RMK2), 1, REGEXP_INSTR(
                TRIM(IBGE.T3RMK2), '[.]'
            ) - 1)
        ) AS CITY,
        TRIM(UNIT.BPZ55REA11) AS LONGITUDE,
        TRIM(UNIT.BPZ55REA10) AS LATITUDE,
        TRIM(UNIT.BPZ55REA03) AS "STATE",
        COALESCE(OWN.TARGET_CODE, UNIT.BPZ55REA05) AS LOCATION_OWNERSHIP,
        TRIM(BP.MCAN8) AS ADDRESS_NUMBER,
        TRIM(COALESCE(HER.MAPA8, BP.MCAN8)) AS ADDRESS_PAI,
        NULL AS LOCATION_IBP_ASSET,
        AB.ABTAX AS CNPJ,
        AB.ABTX2 AS IE,
        TRIM(IBGE_CODE.DRDL02) AS IBGE,
        NULL AS USER_RESERVED_DATE,
        IFF(
            COALESCE(BP.MCUPMJ, 0) = 0,
            NULL,
            TO_CHAR({{ julian_date_to_gregorian('BP', 'MCUPMJ') }}, 'DD-MM-YYYY') -- noqa
        ) AS UPDATED_DATE
    FROM {{ source('jde','F0006') }} AS BP
    LEFT JOIN {{ source('jde','F0116') }} AS ENDE
        ON BP.MCAN8 = ENDE.ALAN8
    LEFT JOIN {{ source('jde','F0101') }} AS AB
        ON BP.MCAN8 = AB.ABAN8
    FULL OUTER JOIN {{ source('jde','F554006') }} AS UNIT
        ON (CASE
            WHEN (
                COALESCE(TRIM(BP.MCRP35), '') = '3'
                AND COALESCE(TRIM(BP.MCRP36), '') >= '1'
            )
                THEN COALESCE(TRIM(BP.MCRP36), '')
            ELSE COALESCE(TRIM(BP.MCRP34), '')
        END) = TRIM(UNIT.BPZ55REUNI)
    LEFT JOIN {{ source('jde','F00092') }} AS IBGE
        ON TRIM(IBGE.T3RMK) = REPLACE(TRIM(UNIT.BPZ55REA07), '        ')
    LEFT JOIN {{ source('jde','F0150') }} AS HER
        ON
            TRIM(BP.MCAN8) = TRIM(HER.MAAN8)
            AND TRIM(HER.MAPA8) != '0'
    LEFT JOIN PRODCTL_F0005 AS IBGE_CODE
        ON
            IBGE_CODE.DRSY = '5504'
            AND IBGE_CODE.DRRT = 'MU'
            AND TRIM(IBGE_CODE.DRKY) = REPLACE(
                REPLACE(REPLACE(
                    TRIM(ENDE.ALCOUN), CHR(9), ' '
                ), CHR(10), ''), CHR(13), ''
            )
    LEFT JOIN PRODCTL_F0005 AS LOC_TP
        ON
            TRIM(LOC_TP.DRSY) = '00'
            AND TRIM(LOC_TP.DRRT) = '35'
            AND TRIM(LOC_TP.DRKY) = TRIM(BP.MCRP35)
    LEFT JOIN CTE_UDC_MAPPING AS OWN
        ON
            UPPER(TRIM(UNIT.BPZ55REA05)) = OWN.SOURCE_CODE
            AND OWN.CATEGORY = 'LOCATION_BRANCHPLANT_OWNERSHIP'
            AND OWN.STAGE = 'LOCATION_BP'
    LEFT JOIN CTE_UDC_MAPPING AS REGIAO
        ON
            UPPER(TRIM(UNIT.BPZ55REA03)) = REGIAO.SOURCE_CODE
            AND REGIAO.CATEGORY = 'LOCATION_REGION'
            AND REGIAO.STAGE = 'LOC_ESTADOS'

    WHERE
        TRIM(BP.MCSTYL) = 'BP'
        AND LENGTH(TRIM(BP.MCMCU)) = 10
        AND (
            TRIM(BP.MCMCU) LIKE ('02171%') OR TRIM(BP.MCMCU) LIKE ('02180%')
            OR TRIM(BP.MCMCU) LIKE ('02191%')
        )
        AND TRIM(IBGE.T3SDB) = 'REAG'
        AND {{ filter_remove_jde_delete_data('UNIT') }} -- noqa
        AND {{ filter_remove_jde_delete_data('BP') }} -- noqa
        AND {{ filter_remove_jde_delete_data('AB') }} -- noqa
        AND {{ filter_remove_jde_delete_data('ENDE') }} -- noqa
        AND {{ filter_remove_jde_delete_data('IBGE') }} -- noqa
)

SELECT
    LOCATIONID,
    LOCATION_UNIT_ID,
    LOCATION_UNIT_STRUCTURE,
    LOCATION_GROUP,
    LOCATION_COUNTRY,
    LOCATION_REGION,
    LOCATION_SUB_REGION,
    LOCATION_NAME,
    LOCATION_TYPE,
    ZIP,
    "ADDRESS",
    COMMENTS,
    ISACTIVE,
    CITY,
    LONGITUDE,
    LATITUDE,
    "STATE",
    LOCATION_OWNERSHIP,
    ADDRESS_NUMBER,
    ADDRESS_PAI,
    LOCATION_IBP_ASSET,
    CNPJ,
    IE,
    IBGE,
    USER_RESERVED_DATE,
    UPDATED_DATE
FROM LOCATION_BP
