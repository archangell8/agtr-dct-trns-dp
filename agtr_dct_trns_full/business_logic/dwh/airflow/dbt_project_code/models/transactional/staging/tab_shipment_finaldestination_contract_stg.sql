{{
    config(
        materialized='table'
    )
}}

WITH
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

CAK_TOTAL AS (
    SELECT
        CSDMCT,
        CASE
            WHEN CSZ55SLPT = '12'
                THEN SUM(CSUORG)
        END AS TOT,
        CASE
            WHEN CSZ55SLPT = '10'
                THEN SUM(CSUORG)
        END AS TOT2
    FROM {{ source('jde', 'F5543050') }}
    WHERE
        CSZ55SLPT IN ('12', '10')
        AND CSZ55SLPS = 'E'
    GROUP BY CSDMCT, CSZ55SLPT
),

CAK_CANCELLED AS (
    SELECT
        PDDMCT,
        SUM(PDUORG) AS CAN
    FROM {{ source('jde', 'F4311') }}
    WHERE
        PDNXTR = '999'
        AND PDLTTR = '980'
        AND PDDCTO IN ('OG', 'O9')
        AND {{ filter_remove_jde_delete_data('F4311') }} --noqa
    GROUP BY PDDMCT
),

FINALDEST_F81 AS (
    SELECT DISTINCT
        F50.CSKCO,
        F50.CSDMCT,
        F50.CSMCU,
        F81.SARLLN AS RLLN,
        COALESCE(
            UDC_AMID.TARGET_CODE, UDC_MODAL_2.TARGET_CODE,
            UDC_MODAL_1.TARGET_CODE, TRIM(F50.CSAA10)
        ) AS CSAA10,
        COALESCE(
            TRY_CAST(F81.SARORN AS NUMBER),
            0
        ) AS FICHA
    FROM {{ source('jde', 'F5543050') }} AS F50
    INNER JOIN {{ source('jde', 'F38010') }} AS F38
        ON
            F50.CSDMCT = F38.DNDMCT
    LEFT JOIN {{ source('jde', 'F5543081') }} AS F81
        ON
            F50.CSZ55SLPN = F81.SAZ55SLPN
            AND F50.CSZ55SLPS = F81.SAZ55SLPS
            AND F50.CSZ55SLPT = F81.SAZ55SLPT
            AND F50.CSKCO = F81.SAKCO
            AND TRY_CAST(F81.SARORN AS NUMBER) > 0
    LEFT JOIN UDC AS UDC_AMID
        ON
            TRIM(UDC_AMID.SOURCE_CODE) = SUBSTR(TRIM(F50.CSMCU), 1, 8)
            AND UDC_AMID.CATEGORY = 'SOURCING CONTRACT'
            AND UDC_AMID.STAGE = 'DESTINATION AMIDOS'
    LEFT JOIN UDC AS UDC_MODAL_1
        ON
            TRIM(UDC_MODAL_1.SOURCE_CODE) = TRIM(F50.CSAA10)
            AND UDC_MODAL_1.CATEGORY = 'LOCATION_CODE'
            AND UDC_MODAL_1.STAGE = 'DESTINATION'
    LEFT JOIN UDC AS UDC_MODAL_2
        ON
            TRIM(UDC_MODAL_2.SOURCE_CODE) = CONCAT(
                TRIM(F50.CSAA10), TRIM(F50.CSMOT)
            )
            AND UDC_MODAL_2.CATEGORY = 'LOCATION_CODE'
            AND UDC_MODAL_2.STAGE = 'DESTINATION'
    LEFT JOIN CAK_TOTAL AS TOT
        ON F50.CSDMCT = TOT.CSDMCT
    LEFT JOIN CAK_CANCELLED AS CAN
        ON F50.CSDMCT = CAN.PDDMCT
    WHERE
        1 = 1
        AND F50.CSZ55SLPT IN ('10', '12')
        AND F50.CSZ55SLPS = 'E'
        AND TRIM(F38.DNDMCT) != ''
        AND CASE
            WHEN
                COALESCE(
                    TRY_CAST(F81.SARORN AS NUMBER),
                    0
                ) > 0
                THEN 0
            ELSE COALESCE(CAN.CAN, 0)
        END != COALESCE(TOT.TOT, TOT.TOT2)
        AND {{ filter_remove_jde_delete_data('F50') }} --noqa
        AND {{ filter_remove_jde_delete_data('F38') }} --noqa
    QUALIFY RANK() OVER (
        PARTITION BY F50.CSKCO, F50.CSDMCT, F50.CSMCU, F81.SARLLN, F81.SARORN
        ORDER BY F81.SAUPMJ DESC, F81.SATDAY DESC
    ) = 1
),

FINALDEST_F43 AS (
    SELECT DISTINCT
        F50.CSKCO,
        F50.CSDMCT,
        F50.CSMCU,
        F43.PDRLLN AS RLLN,
        COALESCE(
            UDC_AMID.TARGET_CODE, UDC_MODAL_2.TARGET_CODE,
            UDC_MODAL_1.TARGET_CODE, TRIM(F50_1.CSAA10), TRIM(F50.CSAA10)
        ) AS CSAA10,
        COALESCE(
            TRY_CAST(F43.PDRORN AS NUMBER),
            0
        ) AS FICHA
    FROM {{ source('jde', 'F5543050') }} AS F50
    INNER JOIN {{ source('jde', 'F38010') }} AS F38
        ON
            F50.CSDMCT = F38.DNDMCT
    INNER JOIN {{ source('jde', 'F4311') }} AS F43
        ON
            F50.CSKCO = F43.PDKCOO
            AND F50.CSDMCT = F43.PDDMCT
            AND F43.PDDCTO IN ('OG', 'O9')
            AND TRY_CAST(F43.PDRORN AS NUMBER) > 0
    LEFT JOIN {{ source('jde', 'F5543081') }} AS F81
        ON
            F43.PDDOCO = F81.SADOCO
            AND F43.PDDCTO = F81.SADCTO
            AND F43.PDOGNO = F81.SALNIX
    LEFT JOIN {{ source('jde', 'F5543050') }} AS F50_1
        ON
            F81.SAZ55SLPN = F50_1.CSZ55SLPN
            AND F81.SAZ55SLPS = F50_1.CSZ55SLPS
            AND F81.SAZ55SLPT = F50_1.CSZ55SLPT
            AND F81.SAKCO = F50_1.CSKCO
    LEFT JOIN UDC AS UDC_AMID
        ON
            TRIM(UDC_AMID.SOURCE_CODE) = SUBSTR(TRIM(F50.CSMCU), 1, 8)
            AND UDC_AMID.CATEGORY = 'SOURCING CONTRACT'
            AND UDC_AMID.STAGE = 'DESTINATION AMIDOS'
    LEFT JOIN UDC AS UDC_MODAL_1
        ON
            TRIM(
                UDC_MODAL_1.SOURCE_CODE
            ) = COALESCE(TRIM(F50_1.CSAA10), TRIM(F50.CSAA10))
            AND UDC_MODAL_1.CATEGORY = 'LOCATION_CODE'
            AND UDC_MODAL_1.STAGE = 'DESTINATION'
    LEFT JOIN UDC AS UDC_MODAL_2
        ON
            TRIM(UDC_MODAL_2.SOURCE_CODE) = CONCAT(
                COALESCE(TRIM(F50_1.CSAA10), TRIM(F50.CSAA10)),
                COALESCE(TRIM(F50_1.CSMOT), TRIM(F50.CSMOT))
            )
            AND UDC_MODAL_2.CATEGORY = 'LOCATION_CODE'
            AND UDC_MODAL_2.STAGE = 'DESTINATION'
    LEFT JOIN CAK_TOTAL AS TOT
        ON F50.CSDMCT = TOT.CSDMCT
    LEFT JOIN CAK_CANCELLED AS CAN
        ON F50.CSDMCT = CAN.PDDMCT
    WHERE
        1 = 1
        AND F50.CSZ55SLPT IN ('12')
        AND F50.CSZ55SLPS = 'E'
        AND TRIM(F38.DNDMCT) != ''
        AND CASE
            WHEN
                COALESCE(
                    TRY_CAST(F43.PDRORN AS NUMBER),
                    0
                ) > 0
                THEN 0
            ELSE COALESCE(CAN.CAN, 0)
        END != COALESCE(TOT.TOT, TOT.TOT2)
        AND {{ filter_remove_jde_delete_data('F50') }} --noqa
        AND {{ filter_remove_jde_delete_data('F38') }} --noqa
        AND {{ filter_remove_jde_delete_data('F43') }} --noqa
),

FINALDEST_TEMP AS (
    SELECT * FROM FINALDEST_F81

    UNION DISTINCT

    SELECT * FROM FINALDEST_F43 AS F43
    WHERE NOT EXISTS (
        SELECT 1 FROM FINALDEST_F81 AS F81
        WHERE
            F81.FICHA = F43.FICHA
            AND F81.RLLN = F43.RLLN
            AND F81.CSDMCT = F43.CSDMCT
            AND F81.CSKCO = F43.CSKCO
    )
),

FINALDESTINATION_CONTRACT AS (
    SELECT
        F55.FICHA,
        F55.RLLN AS LINENUMBER,
        F55.CSAA10 AS DEST,
        TRIM(F55.CSDMCT) AS CONTRACTNUMBER,
        COALESCE(MAX(BP2.LOCATIONID), MAX(BP.LOCATIONID)) AS LOCATIONID
    FROM {{ ref('tab_location_internal_stg') }} AS BP
    LEFT JOIN FINALDEST_TEMP AS F55
        ON
            TRIM(F55.CSAA10) = BP.LOCATION_CODE
            AND F55.CSKCO = CASE
                WHEN
                    BP.LOCATION_CODE = 'TUB'
                    THEN F55.CSKCO
                ELSE
                    CONCAT('5', SUBSTR(BP.LOCATIONID, 2, 4))
            END
            --AND F55.CSKCO = CONCAT('5', SUBSTR(BP.LOCATIONID, 2, 4))
    LEFT JOIN UDC
        ON
            UDC.SOURCE_CODE = TRIM(F55.CSAA10)
            AND UDC.CATEGORY = 'SHIPMENT'
            AND UDC.STAGE = 'CIF_TERMINAL'
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS BP2
        ON
            UDC.TARGET_CODE = BP2.LOCATION_UNIT_ID
            AND SUBSTR(F55.CSMCU, 1, 5) = SUBSTR(BP2.LOCATIONID, 1, 5)
    WHERE
        1 = 1
        AND BP.ISACTIVE = 'TRUE'
        AND BP.LOCATION_UNIT_STRUCTURE IN (
            'FÁBRICA', 'PORTO MARÍTIMO', 'MERCADO INTERNO'
        )
    GROUP BY
        TRIM(F55.CSDMCT),
        F55.FICHA,
        F55.RLLN,
        F55.CSAA10
)

SELECT DISTINCT
    FICHA,
    LOCATIONID,
    CONTRACTNUMBER,
    LINENUMBER,
    DEST
FROM FINALDESTINATION_CONTRACT
QUALIFY RANK() OVER (
    PARTITION BY FICHA, CONTRACTNUMBER, LINENUMBER
    ORDER BY DEST
) = 1
