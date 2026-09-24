--noqa: disable=all
{{
    config(
        materialized='table',
        tags=['contracts']
    )
}}

WITH
CTE_F0005_STATUS AS (
    SELECT
        TRIM(F05.DRDL01) AS DRDL01,
        TRIM(F05.DRKY) AS DRKY
    FROM {{ source('jde', 'PRODCTL_F0005') }} AS F05
    WHERE
        1 = 1
        AND F05.DRSY = '38'
        AND F05.DRRT = 'CU'
        AND {{ filter_remove_jde_delete_data('F05') }} -- noqa
),

CTE_SLIP_COMPRA AS (
    SELECT
        F50_INT.CSDMCT,
        F50_INT.CSKCO,
        MAX(F50_INT.CSZ55SLPN) AS SLIP
    FROM {{ source('jde', 'F5543050') }} AS F50_INT
    WHERE
        F50_INT.CSZ55SLPT = '12'
        AND F50_INT.CSZ55SLPS = 'E'
        AND {{ filter_remove_jde_delete_data('F50_INT') }} -- noqa
    GROUP BY
        F50_INT.CSDMCT,
        F50_INT.CSKCO
),

DATE_INIT AS (
    SELECT
        TRIM(F43.PDDMCT) AS CONTRACT_NUMBER,
        MIN(NULLIF(TRIM(F43.PDTRDJ), 0)) AS DELIVERYSTART,
        MAX(F43.PDFRTH) AS FREIGHT_TYPE
    FROM {{ source('jde', 'F4311') }} AS F43
    WHERE
        F43.PDDCTO = 'OH'
        AND F43.PDLTTR != '980' --Fichas canceladas
        AND {{ filter_remove_jde_delete_data('F43') }} -- noqa
    GROUP BY F43.PDDMCT
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

OH_GLOBAL AS (
    SELECT DISTINCT RTDMT1
    FROM {{ source('jde', 'F5543220') }}
),

DETAILS AS (
    SELECT
        CIA,
        AGREEMENT_NUMBER,
        COALESCE(NULLIF(TRIM(DESTINATION), ''), 'N/A') AS DESTINATION,
        SUM(SALDO_EM_ABERTO_REM) AS OPEN_OHGLOBAL
    FROM {{ source('jde', 'F_PURCHASE_POSITION') }}
    WHERE
        1 = 1
    GROUP BY
        CIA,
        AGREEMENT_NUMBER,
        COALESCE(NULLIF(TRIM(DESTINATION), ''), 'N/A')
),

DESTINATION AS (
    SELECT DISTINCT
        COALESCE(NULLIF(TRIM(F50_INT.CSDMCT), ''), F50_INT.CSZ55SLPN) AS CSDMCT,
        F50_INT.CSKCO,
        COALESCE(
            UDC_AMID.TARGET_CODE, --RECOMERA DEST AMIDOS
            UDC_MODAL_2.TARGET_CODE, --RECUPERA DEST DE-PARA CONCAT DEST E MODAL
            UDC_MODAL_1.TARGET_CODE, --RECUPERA DEST DE-PARA
            COALESCE(NULLIF(TRIM(F50_INT.CSAA10), ''), 'N/A')
        ) AS DESTINATION,
        COALESCE(
            UDC_TRANSMODE.TARGET_CODE,
            IFF(TRIM(F50_INT.CSMOT) > '0', TRIM(F50_INT.CSMOT), 'ROD')
        ) AS TRANSMODE
    FROM {{ source('jde', 'F5543050') }} AS F50_INT
    LEFT JOIN UDC AS UDC_AMID
        ON
            TRIM(UDC_AMID.SOURCE_CODE) = SUBSTR(TRIM(F50_INT.CSMCU), 1, 8)
            AND UDC_AMID.CATEGORY = 'SOURCING CONTRACT'
            AND UDC_AMID.STAGE = 'DESTINATION AMIDOS'
    LEFT JOIN UDC AS UDC_MODAL_1
        ON
            TRIM(UDC_MODAL_1.SOURCE_CODE) = TRIM(F50_INT.CSAA10)
            AND UDC_MODAL_1.CATEGORY = 'LOCATION_CODE'
            AND UDC_MODAL_1.STAGE = 'DESTINATION'
    LEFT JOIN UDC AS UDC_MODAL_2
        ON
            TRIM(UDC_MODAL_2.SOURCE_CODE) = CONCAT(
                TRIM(F50_INT.CSAA10), TRIM(F50_INT.CSMOT)
            )
            AND UDC_MODAL_2.CATEGORY = 'LOCATION_CODE'
            AND UDC_MODAL_2.STAGE = 'DESTINATION'
    LEFT JOIN UDC AS UDC_TRANSMODE
        ON
            TRIM(F50_INT.CSAA10) = SPLIT_PART(
                UDC_TRANSMODE.SOURCE_CODE, '-', 1
            )
            AND TRIM(F50_INT.CSMOT) = SPLIT_PART(
                UDC_TRANSMODE.SOURCE_CODE, '-', 2
            )
            AND UDC_TRANSMODE.CATEGORY = 'LOCATION_CODE'
            AND UDC_TRANSMODE.STAGE = 'TRANSMODE'
    WHERE
        F50_INT.CSZ55SLPT IN ('12', '10')
        AND F50_INT.CSZ55SLPS IN ('E', 'P')
        AND {{ filter_remove_jde_delete_data('F50_INT') }} -- noqa
),

CHANGED_DESTINATION AS (
    SELECT
        TRIM(C.CSAA10) AS DEST_ORIGINAL,
        TRIM(C.CSDMCT) AS CAK_ORIGINAL,
        TRIM(B.CSZ55SLPN) AS SLIP_ALT,
        TRIM(A.CSAA10) AS DEST_ATUAL,
        TRIM(A.CSDMCT) AS CAK_ATUAL
    FROM {{ source('jde', 'F5543050') }} AS A --base do contrato em validação
    --busca pelo slip de alteração para recuperar contrato original
    LEFT JOIN {{ source('jde', 'F5543050') }} AS B
        ON
            A.CSZ55SLPM = B.CSZ55SLPN
            AND A.CSKCO = B.CSKCO
            AND B.CSZ55SLPT = '03'
            AND B.CSZ55SLPS = 'E'
            AND {{ filter_remove_jde_delete_data('B') }}
    --busca pelo slip de compra do contrato original para recuperar adestinação
    LEFT JOIN {{ source('jde', 'F5543050') }} AS C
        ON B.CSKCO = C.CSKCO
        AND B.CSDMCT = C.CSDMCT
        AND C.CSZ55SLPT = '12'
        AND C.CSZ55SLPS = 'E'
        AND {{ filter_remove_jde_delete_data('C') }}
    WHERE
        1 = 1
        AND A.CSKCO IN ('52171', '52191', '52180')
        AND A.CSZ55SLPT = '12'
        AND A.CSZ55SLPS = 'E'
        AND TRIM(REPLACE(C.CSAA10, 'MI')) != TRIM(REPLACE(A.CSAA10, 'MI'))
        AND A.CSUPMJ > 123000
        AND {{ filter_remove_jde_delete_data('A') }}
),

HEADER_CAK AS (
    SELECT DISTINCT
        F43.PDKCOO AS CIA,
        CONCAT(F43.PDKCOO, '-', TRIM(F43.PDDMCT)) AS ID,
        TRIM(F43.PDDMCT) AS CONTRACTNUMBER,
        TRIM(F43.PDAN8) AS SUPPLIERID,
        CASE
            WHEN COALESCE(TRIM(F64.LRAN8), 0) > 0
                THEN TRIM(F64.LRAN8)
            ELSE
                TRIM(COALESCE(NULLIF(F50.CSSHAN, 0), F43.PDSHAN))
        END AS SOURCE,
        TRIM(COALESCE(NULLIF(F50.CSSHAN, 0), F43.PDSHAN)) AS FARM,
        NULLIF(TRIM(DEST.DESTINATION), '') AS DESTINATION,
        TRIM(F43.PDMCU) AS DELIVERY,
        UNIT2.LOCATION_UNIT_ID AS DELIVERYUNITID,
        TRIM(F50.CSEMCU) AS ORIGINATION, --a
        UNIT_O.LOCATION_UNIT_ID AS ORIGINATIONUNITID, --noqa
        DEST.TRANSMODE,
        COALESCE(TRIM(F51.HSFRTH), DI.FREIGHT_TYPE) AS FREIGHTTYPE,
        CASE
            WHEN NULLIF(F51.HSZ55DTIE, 0) IS NOT NULL
                THEN {{ julian_date_to_gregorian('F51', 'HSZ55DTIE') }}
            ELSE NULL
        END AS DELIVERYSTART_CAK,
        CASE
            WHEN NULLIF(F51.HSZ55DTFE, 0) IS NOT NULL
                THEN {{ julian_date_to_gregorian('F51', 'HSZ55DTFE') }}
            ELSE NULL
        END AS DELIVERYEND,
        {{ julian_date_to_gregorian('DI', 'DELIVERYSTART') }} AS DELIVERYSTART_OH,
        CASE
            WHEN DET.OPEN_OHGLOBAL > 0
                THEN 'Active'
            ELSE CTE_F0005_STATUS.DRDL01
        END AS "STATUS",
        TRIM(F50.CSTORG) AS SALESREP,
        TRIM(UNIT.BPZ55REA02) AS LOCATION_SUB_REGION,
        TRIM(F43.PDTRDJ) AS TRANSACTION_DATE,
        TRIM(F01.ABALPH) AS SALESREPNAME,--noqa
        F51.HSBINM AS FISCALCONDITION,
        F51.HSZ55TPCP AS "TYPE",
        CASE
            WHEN F51.HSDDJ = '0' THEN 'N/A'
            ELSE
                TO_CHAR(
                    {{ julian_date_to_gregorian('F51', 'HSDDJ') }}, -- noqa
                    'DD-MM-YYYY'
                )
        END AS PAYMENTDATE,
        F51.HSPTC AS PAYMENTDETAILS,
        CASE
            WHEN LEFT(TRIM(F50.CSAA10), 3) = 'MI '
                THEN -1
            ELSE 0
        END AS PRIORITY,
        CASE
            WHEN F220.RTDMT1 IS NOT NULL
                THEN 'TRUE'
            ELSE
                'FALSE'
        END AS GLOBALINVOICE,
        F51.HSZD09 AS HARVEST,
        COALESCE(
            CASE
                WHEN NULLIF(F50.CSTRDJ, 0) IS NOT NULL
                    THEN {{ julian_date_to_gregorian('F50', 'CSTRDJ') }}
                ELSE NULL
            END,
            CASE
                WHEN NULLIF(F43.PDTRDJ, 0) IS NOT NULL
                    THEN {{ julian_date_to_gregorian('F43', 'PDTRDJ') }}
                ELSE NULL
            END
        ) AS PURCHASEDATE,
        --se o contrato existe na cte "changed_destination" o campo recebe
        -- a string "TRUE"
        IFF(
            CHANGED.CAK_ATUAL IS NOT NULL, 'TRUE', 'FALSE'
        ) AS ISSLIPWITHCHANGEDDESTINATION
    FROM {{ source('jde', 'F4311') }} AS F43
    LEFT JOIN {{ source('jde', 'F5543050') }} AS F50
        ON
            F50.CSDMCT = F43.PDDMCT
            AND F50.CSMCU = F43.PDMCU
            AND F50.CSZ55SLPS = 'E'
            AND F50.CSZ55SLPT IN ('10', '12')
            AND {{ filter_remove_jde_delete_data('F50') }}
    LEFT JOIN DESTINATION AS DEST
        ON
            DEST.CSDMCT = TRIM(F50.CSDMCT)
            AND DEST.CSKCO = F50.CSKCO
    LEFT JOIN OH_GLOBAL AS F220
        ON TRIM(F43.PDDMCT) = TRIM(F220.RTDMT1)
    LEFT JOIN DETAILS AS DET
        ON
            TRIM(DET.CIA) = TRIM(F43.PDKCOO)
            AND TRIM(DET.AGREEMENT_NUMBER) = TRIM(F43.PDDMCT)
            AND DET.DESTINATION = DEST.DESTINATION
    --para amidos, muitos contratos nao tem destination, necessario de-para
    -- por BP para descobrir a destinação

    LEFT JOIN CTE_SLIP_COMPRA AS F50_INT
        ON
            F50.CSDMCT = F50_INT.CSDMCT
            AND F50.CSKCO = F50_INT.CSKCO
            AND F50.CSZ55SLPN = F50_INT.SLIP
    LEFT JOIN DATE_INIT AS DI
        ON DI.CONTRACT_NUMBER = TRIM(F43.PDDMCT)
    LEFT JOIN {{ source('jde', 'F5543051') }} AS F51
        ON
            F50.CSKCO = F51.HSKCO
            AND F50.CSZ55SLPN = F51.HSZ55SLPN
            AND F50.CSZ55SLPT = F51.HSZ55SLPT
            AND F50.CSZ55SLPS = F51.HSZ55SLPS
            AND {{ filter_remove_jde_delete_data('F51') }}
    INNER JOIN {{ source('jde', 'F38010') }} AS F38
        ON F43.PDDMCT = F38.DNDMCT
    INNER JOIN {{ source('jde', 'F0006') }} AS F06_A
        ON F06_A.MCMCU = F43.PDMCU
    LEFT JOIN {{ source('jde', 'F0006') }} AS F06_B
        ON F06_B.MCMCU = F50.CSEMCU
    LEFT JOIN CTE_F0005_STATUS
        ON CTE_F0005_STATUS.DRKY = TRIM(F38.DNDMSC)
    FULL OUTER JOIN {{ source('jde', 'F554006') }} AS UNIT
        ON (CASE
            WHEN (TRIM(F06_A.MCRP35) = '3' AND TRIM(F06_A.MCRP36) >= '1')
                THEN TRIM(F06_A.MCRP36)
            ELSE TRIM(F06_A.MCRP34)
        END) = TRIM(UNIT.BPZ55REUNI)
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS UNIT2
        ON TRIM(UNIT2.LOCATIONID) = TRIM(F06_A.MCMCU)
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS UNIT_O
        ON TRIM(UNIT_O.LOCATIONID) = TRIM(F06_B.MCMCU)
    LEFT JOIN {{ source('jde', 'F5543064') }} AS F64
        ON
            F50.CSKCO = F64.LRKCO
            AND F50.CSZ55SLPN = F64.LRZ55SLPN
            AND F50.CSZ55SLPT = F64.LRZ55SLPT
            AND LEN(TRIM(F64.LRAN8)) >= 8
            AND {{ filter_remove_jde_delete_data('F64') }} -- noqa
    LEFT JOIN {{ source('jde', 'F0092') }} AS F92
        ON TRIM(F50.CSTORG) = TRIM(F92.ULUSER)
    LEFT JOIN {{ source('jde', 'F0101') }} AS F01
        ON F92.ULAN8 = F01.ABAN8
    INNER JOIN {{ ref('item_master') }} AS IT
        ON TRIM(F43.PDLITM) = TRIM(IT.ITEM)
    LEFT JOIN UDC AS REMOVE_CTR
        ON
            REMOVE_CTR.CATEGORY = 'SOURCING CONTRACT'
            AND REMOVE_CTR.STAGE = 'REMOVER CTR'
            AND TRIM(REMOVE_CTR.SOURCE_CODE) = TRIM(F43.PDDMCT)
    LEFT JOIN CHANGED_DESTINATION AS CHANGED
        ON TRIM(F50.CSDMCT) = CHANGED.CAK_ATUAL
    WHERE
        1 = 1
        AND F38.DNDMCT != ''
        AND F43.PDKCOO IN ('52171', '52191', '52180')
        AND F43.PDDCTO IN ('OG', 'O9')
        AND F43.PDLNID = 1000
        AND F43.PDUORG != 0
        AND (
            F43.PDTRDJ >= 125001
            OR EXISTS (
                SELECT 1
                FROM {{ source('jde', 'F4311') }} AS A
                WHERE
                    A.PDDMCT = F43.PDDMCT
                    AND A.PDDCTO = 'OH'
                    AND A.PDTRDJ > 125000
                    AND A.PDLTTR != '980' --Fichas canceladas
                    AND {{ filter_remove_jde_delete_data('A') }} -- noqa
            )
        )
        -- REMOVER CONTRATOS ANTIGOS EM ABERTO QUE NAO PODEM SER CANCELADOS
        AND REMOVE_CTR.SOURCE_CODE IS NULL
        AND {{ filter_remove_jde_delete_data('F43') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F38') }} -- noqa
    QUALIFY RANK() OVER (
            PARTITION BY TRIM(F43.PDDMCT)
            ORDER BY F50.CSZ55SLPT DESC, F50.CSZ55SLPN ASC
        ) = 1
),

HEADER_SLIP_PENDENTE AS (
    SELECT DISTINCT
        F50.CSKCO AS CIA,
        CONCAT(F50.CSKCO, '-', TRIM(F50.CSZ55SLPN)) AS ID,
        TRIM(F50.CSZ55SLPN) AS CONTRACTNUMBER,
        COALESCE(NULLIF(TRIM(F50.CSAN8), 0), F06_B.MCAN8) AS SUPPLIERID,
        COALESCE(NULLIF(
            CASE
                WHEN COALESCE(TRIM(F64.LRAN8), 0) > 0
                    THEN TRIM(F64.LRAN8)
                ELSE
                    TRIM(F50.CSSHAN)
            END, 0
        ), F06_B.MCAN8) AS SOURCE,
        COALESCE(NULLIF(TRIM(F50.CSSHAN), 0), F06_B.MCAN8) AS FARM,
        NULLIF(TRIM(DEST.DESTINATION), '') AS DESTINATION,
        TRIM(F50.CSMCU) AS DELIVERY,
        UNIT2.LOCATION_UNIT_ID AS DELIVERYUNITID,
        TRIM(F50.CSEMCU) AS ORIGINATION,
        UNIT_O.LOCATION_UNIT_ID AS ORIGINATIONUNITID, --noqa
        DEST.TRANSMODE,
        TRIM(F51.HSFRTH) AS FREIGHTTYPE,
        CASE
            WHEN NULLIF(F51.HSZ55DTIE, 0) IS NOT NULL
                THEN {{ julian_date_to_gregorian('F51', 'HSZ55DTIE') }}
            ELSE NULL
        END AS DELIVERYSTART_CAK,
        NULL AS DELIVERYSTART_OH,
        CASE
            WHEN NULLIF(F51.HSZ55DTFE, 0) IS NOT NULL
                THEN {{ julian_date_to_gregorian('F51', 'HSZ55DTFE') }}
            ELSE NULL
        END AS DELIVERYEND,
        'Pendente' AS "STATUS",
        TRIM(F50.CSTORG) AS SALESREP,
        TRIM(UNIT.BPZ55REA02) AS LOCATION_SUB_REGION,
        TRIM(F50.CSTRDJ) AS TRANSACTION_DATE,
        TRIM(F01.ABALPH) AS SALESREPNAME,--noqa
        F51.HSBINM AS FISCALCONDITION,
        F51.HSZ55TPCP AS "TYPE",
        CASE
            WHEN F51.HSDDJ = '0' THEN 'N/A'
            ELSE
                TO_CHAR(
                    {{ julian_date_to_gregorian('F51', 'HSDDJ') }}, -- noqa
                    'DD-MM-YYYY'
                )
        END AS PAYMENTDATE,
        F51.HSPTC AS PAYMENTDETAILS,
        CASE
            WHEN LEFT(TRIM(F50.CSAA10), 3) = 'MI '
                THEN -1
            ELSE 0
        END AS PRIORITY, --F06Z.INT01
        'FALSE' AS GLOBALINVOICE,
        F51.HSZD09 AS HARVEST,
        CASE
            WHEN NULLIF(F50.CSTRDJ, 0) IS NOT NULL
                THEN {{ julian_date_to_gregorian('F50', 'CSTRDJ') }}
            ELSE NULL
        END AS PURCHASEDATE,
        'FALSE' AS ISSLIPWITHCHANGEDDESTINATION
    FROM {{ source('jde', 'F5543050') }} AS F50
    INNER JOIN {{ source('jde', 'F5543051') }} AS F51
        ON
            F50.CSKCO = F51.HSKCO
            AND F50.CSZ55SLPN = F51.HSZ55SLPN
            AND F50.CSZ55SLPT = F51.HSZ55SLPT
            AND F50.CSZ55SLPS = F51.HSZ55SLPS
    LEFT JOIN {{ source('jde', 'F5543064') }} AS F64
        ON
            F50.CSKCO = F64.LRKCO
            AND F50.CSZ55SLPN = F64.LRZ55SLPN
            AND F50.CSZ55SLPT = F64.LRZ55SLPT
            AND LEN(TRIM(F64.LRAN8)) >= 8
            AND {{ filter_remove_jde_delete_data('F64') }} -- noqa
    INNER JOIN {{ source('jde', 'F0006') }} AS F06_A
        ON F06_A.MCMCU = F50.CSMCU
    LEFT JOIN {{ source('jde', 'F0006') }} AS F06_B
        ON F06_B.MCMCU = F50.CSEMCU
    FULL OUTER JOIN {{ source('jde', 'F554006') }} AS UNIT
        ON (CASE
            WHEN (TRIM(F06_A.MCRP35) = '3' AND TRIM(F06_A.MCRP36) >= '1')
                THEN TRIM(F06_A.MCRP36)
            ELSE TRIM(F06_A.MCRP34)
        END) = TRIM(UNIT.BPZ55REUNI)
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS UNIT2
        ON TRIM(UNIT2.LOCATIONID) = TRIM(F06_A.MCMCU)
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS UNIT_O
        ON TRIM(UNIT_O.LOCATIONID) = TRIM(F06_B.MCMCU)
    LEFT JOIN DESTINATION AS DEST
        ON
            DEST.CSDMCT = F50.CSZ55SLPN
            AND DEST.CSKCO = F50.CSKCO
    LEFT JOIN {{ source('jde', 'F0092') }} AS F92
        ON TRIM(F50.CSTORG) = TRIM(F92.ULUSER)
    LEFT JOIN {{ source('jde', 'F0101') }} AS F01
        ON F92.ULAN8 = F01.ABAN8
    INNER JOIN {{ ref('item_master') }} AS IT
        ON TRIM(F50.CSLITM) = TRIM(IT.ITEM)
    WHERE
        1 = 1
        AND F50.CSZ55SLPS = 'P'
        AND F50.CSZ55SLPT IN ('12')
        AND F50.CSKCO IN ('52171', '52191', '52180')
        AND F50.CSUORG != 0
        AND TRIM(F51.HSZ55TPCP) != 'NPE'
        AND {{ filter_remove_jde_delete_data('F50') }}
        AND {{ filter_remove_jde_delete_data('F51') }}
),

HEADER AS (
    SELECT
        *,
        IFF(
            COALESCE(
                HEADER_CAK.DELIVERYSTART_CAK,
                HEADER_CAK.DELIVERYSTART_OH,
                DATE_TRUNC('MONTH', HEADER_CAK.DELIVERYEND)
            ) < TO_DATE('01-01-2024', 'DD-MM-YYYY'),
            HEADER_CAK.DELIVERYEND,
            COALESCE(
                HEADER_CAK.DELIVERYSTART_CAK,
                HEADER_CAK.DELIVERYSTART_OH,
                DATE_TRUNC('MONTH', HEADER_CAK.DELIVERYEND)
            )
        ) AS DELIVERYSTART_FINAL
    FROM HEADER_CAK

    UNION ALL

    SELECT
        *,
        IFF(
            COALESCE(
                HEADER_SLIP_PENDENTE.DELIVERYSTART_CAK,
                HEADER_SLIP_PENDENTE.DELIVERYSTART_OH,
                DATE_TRUNC('MONTH', HEADER_SLIP_PENDENTE.DELIVERYEND)
            ) < TO_DATE('01-01-2024', 'DD-MM-YYYY'),
            HEADER_SLIP_PENDENTE.DELIVERYEND,
            COALESCE(
                HEADER_SLIP_PENDENTE.DELIVERYSTART_CAK,
                HEADER_SLIP_PENDENTE.DELIVERYSTART_OH,
                DATE_TRUNC('MONTH', HEADER_SLIP_PENDENTE.DELIVERYEND)
            )
        ) AS DELIVERYSTART_FINAL
    FROM HEADER_SLIP_PENDENTE
),

CONT AS (
    SELECT
        CONTRACTNUMBER,
        CIA,
        COUNT(*) AS QTDE
    FROM HEADER
    GROUP BY
        CONTRACTNUMBER,
        CIA
    HAVING COUNT(*) > 1
),

SOURCING_CONTRACT AS (
    SELECT DISTINCT
        COALESCE(NULLIF(
            CASE
                WHEN (
                    CONT.CONTRACTNUMBER IS NOT NULL
                    AND NOT (
                        HEADER.GLOBALINVOICE = 'TRUE'
                        AND HEADER.FREIGHTTYPE != 'CIF'
                    )
                )
                    THEN CONCAT(HEADER.ID, '-', HEADER.DESTINATION)
                ELSE
                    HEADER.ID
            END,
            ''
        ), 'N/A') AS ID,
        COALESCE(NULLIF(
            CASE
                WHEN (
                    CONT.CONTRACTNUMBER IS NOT NULL
                    AND NOT (
                        HEADER.GLOBALINVOICE = 'TRUE'
                        AND HEADER.FREIGHTTYPE != 'CIF'
                    )
                )
                    THEN CONCAT(HEADER.CONTRACTNUMBER, '-', HEADER.DESTINATION)
                ELSE
                    HEADER.CONTRACTNUMBER
            END,
            ''
        ), 'N/A') AS CONTRACTNUMBER,
        COALESCE(NULLIF(HEADER.SUPPLIERID, ''), 'N/A') AS SUPPLIERID,
        COALESCE(NULLIF(HEADER.SOURCE, ''), 'N/A') AS SOURCEBP,
        COALESCE(NULLIF(HEADER.SOURCE, ''), 'N/A') AS SOURCE,
        COALESCE(NULLIF(HEADER.FARM, ''), 'N/A') AS FARM,
        COALESCE(NULLIF(HEADER.DESTINATION, ''), 'N/A') AS DESTINATION,
        COALESCE(NULLIF(HEADER.DELIVERY, ''), 'N/A') AS DELIVERY,
        COALESCE(NULLIF(HEADER.DELIVERYUNITID, ''), 'N/A') AS DELIVERYUNITID,
        CASE
            WHEN
                COALESCE(NULLIF(HEADER.FREIGHTTYPE, ''), 'N/A') = 'FBZ'
                THEN COALESCE(NULLIF(HEADER.DELIVERY, ''), 'N/A')
            ELSE COALESCE(NULLIF(HEADER.ORIGINATION, ''), 'N/A')
        END AS ORIGINATION,
        -- COALESCE(NULLIF(HEADER.ORIGINATION, ''), 'N/A') AS ORIGINATION,
        COALESCE(NULLIF(HEADER.ORIGINATIONUNITID, ''), 'N/A')
            AS ORIGINATIONUNITID,
        COALESCE(NULLIF(HEADER.TRANSMODE, ''), 'ROD') AS TRANSMODE,
        COALESCE(NULLIF(HEADER.FREIGHTTYPE, ''), 'CIF') AS FREIGHTTYPE,
        COALESCE(NULLIF(
            TO_CHAR(HEADER.DELIVERYSTART_FINAL, 'DD-MM-YYYY'), ''
        ), 'N/A') AS DELIVERYSTART,
        COALESCE(NULLIF(TO_CHAR(
            COALESCE(
                HEADER.DELIVERYEND,
                LAST_DAY(HEADER.DELIVERYSTART_FINAL),
                LAST_DAY(HEADER.PURCHASEDATE)
            ), 'DD-MM-YYYY'
        ), ''), 'N/A') AS DELIVERYEND,
        COALESCE(NULLIF(HEADER.STATUS, ''), 'N/A') AS "STATUS",
        COALESCE(NULLIF(HEADER.LOCATION_SUB_REGION, ''), 'N/A')
            AS LOCATION_SUB_REGION,
        COALESCE(NULLIF(CONCAT(
            HEADER.SALESREP, '-', HEADER.SALESREPNAME
        ), ''), 'N/A') AS SALESREP,
        COALESCE(NULLIF(HEADER.FISCALCONDITION, ''), 'N/A') AS FISCALCONDITION,
        COALESCE(NULLIF(HEADER.TYPE, ''), 'N/A') AS "TYPE",
        COALESCE(NULLIF(HEADER.PAYMENTDATE, ''), 'N/A') AS PAYMENTDATE,
        COALESCE(NULLIF(HEADER.PAYMENTDETAILS, ''), 'N/A') AS PAYMENTDETAILS,
        COALESCE(HEADER.PRIORITY::INT, 0) AS PRIORITY,
        COALESCE(NULLIF(HEADER.GLOBALINVOICE, ''), 'FALSE') AS GLOBALINVOICE,
        COALESCE(NULLIF(HEADER.HARVEST, ''), 'N/A') AS HARVEST,
        COALESCE(
            NULLIF(HEADER.CONTRACTNUMBER, ''), 'N/A'
        ) AS CONTRACTNUMBER_INTERNAL,
        COALESCE(NULLIF(HEADER.CIA, ''), 'N/A') AS CIA,
        COALESCE(NULLIF(
            TO_CHAR( HEADER.PURCHASEDATE, 'DD-MM-YYYY'), ''
        ), 'N/A') AS PURCHASEDATE,
        COALESCE(
            NULLIF(HEADER.ISSLIPWITHCHANGEDDESTINATION, ''), 'FALSE'
        ) AS ISSLIPWITHCHANGEDDESTINATION
    FROM HEADER
    LEFT JOIN CONT
        ON
            HEADER.CONTRACTNUMBER = CONT.CONTRACTNUMBER
            AND HEADER.CIA = CONT.CIA
)

SELECT
    *,
    HASH(*) AS HASH_ID -- noqa
FROM SOURCING_CONTRACT
WHERE DELIVERYEND != 'N/A'
