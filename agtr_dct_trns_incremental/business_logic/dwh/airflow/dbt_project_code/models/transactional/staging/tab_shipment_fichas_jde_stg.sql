-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}

WITH

F5543081 AS (
    SELECT
        T24.SADOCO,
        T24.SADCTO,
        T24.SASFXO,
        T24.SALNID,
        T24.SALTYI,
        T24.SAKCOO,
        T24.SARORN,
        T24.SARCTO,
        T24.SARLLN,
        ROW_NUMBER() OVER (
            PARTITION BY T24.SADOCO, T24.SADCTO, T24.SASFXO, T24.SALNID, T24.SAKCOO
            ORDER BY T24.SAUOPN
        ) AS VOLUME_PRIORITY --priorizando linha com maior volume
    FROM {{ source('jde', 'F5543081') }} AS T24
    WHERE
        T24.SAZ55SLPS = 'E'
        AND T24.SALTYI IN ('SF','S2')
        AND (
            COALESCE(T24.OP_TYPE, '-') NOT IN ('0', '3')
            OR (
                T24.OP_TYPE = '0'
                AND T24.OP_TIME = '1969-12-31 16:00:00.000'
            )
        )
    -- QUALIFY
    --     VOLUME_PRIORITY = 1
),

BP AS (
    SELECT
        L.LOCATIONID AS LOCATION_FROM,
        MAX(LD.LOCATIONID) AS LOCATION_TO
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }} AS LN
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS L
        ON LN.SOURCE_CODE = L.LOCATION_IBP_ASSET
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LD
        ON
            LN.TARGET_CODE = LD.LOCATION_IBP_ASSET
            AND SUBSTR(L.LOCATIONID, 1, 5) = SUBSTR(LD.LOCATIONID, 1, 5)
    WHERE
        1 = 1
        AND LN.CATEGORY = 'LANE'
        AND LN.STAGE = 'ITEM_LANE_TRANSMODE'
        AND L.LOCATION_UNIT_STRUCTURE IN ('TRANSBORDO', 'PORTO FLUVIAL')
        AND L.ISACTIVE = 'TRUE'
        AND LD.ISACTIVE = 'TRUE'
        AND LD.LOCATION_UNIT_STRUCTURE IN ('PORTO MARÍTIMO')
    GROUP BY
        L.LOCATIONID
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

CONTRACT_LOCATION_INTERNAL_STG AS (
    SELECT
       LOCATIONID,
       ISACTIVE
    FROM {{ ref('tab_location_internal_stg') }}
),

VALID_CONTRACTS AS (
    SELECT
        SC.CONTRACTNUMBER_INTERNAL AS CONTRACTNUMBER,
        COALESCE(SUM(SD.TORECEIVETOTAL), 0) AS TORECEIVETOTAL
    FROM {{ ref('tab_sourcing_contract_stg') }} AS SC
    INNER JOIN {{ ref('tab_sourcing_contract_details_stg') }} AS SD
        ON SD.SOURCINGCONTRACTID = SC.ID
    GROUP BY 1
    HAVING COALESCE(SUM(SD.TORECEIVETOTAL), 0) > 0
),

SCHEDULED_CONTRACTS AS (
    SELECT DISTINCT
        S.LOCATIONID AS SOURCE,
        T.ADDRESS_PRODUTOR,
        D.LOCATIONID AS DESTINATION,
        DECODE(T.TIPO_OPERACAO, 'FBZ', 'CIF', T.TIPO_OPERACAO) AS FREIGHTYPE,
        T.CONTRACT_NUMBER AS CONTRACTNUMBER,
        ROW_NUMBER() OVER (
            PARTITION BY SOURCE, DESTINATION, T.ADDRESS_PRODUTOR
            ORDER BY T.DATE_TIME DESC
        ) AS PRIORITY_1,
        ROW_NUMBER() OVER (
            PARTITION BY DESTINATION, T.ADDRESS_PRODUTOR
            ORDER BY T.DATE_TIME DESC
        ) AS PRIORITY_2
    FROM CONTRACT_LOCATION_INTERNAL_STG AS S
    INNER JOIN {{ ref('tab_cmm_stg') }} AS T
        ON T.ADDRESS_COLETA = S.LOCATIONID
    INNER JOIN CONTRACT_LOCATION_INTERNAL_STG AS D
        ON T.BP_DESTINO = D.LOCATIONID
    INNER JOIN VALID_CONTRACTS AS CC
        ON CC.CONTRACTNUMBER = T.CONTRACT_NUMBER
    WHERE
        1 = 1
        AND D.ISACTIVE = 'TRUE'
        AND T.TIPO_OPERACAO IN ('FOB', 'FBZ')
        AND T.FIRSTDAYOFWEEK = DATE_TRUNC(WEEK, CURRENT_DATE())
),

F4311_CTE AS (
    SELECT * FROM {{ source('jde', 'F4311') }} AS F43
    INNER JOIN {{ source('jde', 'F38010') }} AS F38
        ON
            F43.PDDMCT = F38.DNDMCT
    WHERE
        1 = 1
        AND TRIM(F38.DNDMCT) != ''
        AND F43.PDKCOO IN ('52171', '52191', '52180')
        AND F43.PDDCTO IN ('OG', 'O9')
        AND F43.PDLNID = 1000
        AND (
            F43.PDTRDJ >= 125001
            OR EXISTS (
                SELECT 1
                FROM {{ source('jde', 'F4311') }} AS A
                WHERE
                    A.PDDMCT = F43.PDDMCT
                    AND A.PDDCTO = 'OH'
                    AND A.PDTRDJ > 125000
            )
            OR TRIM(F38.DNDMSC) = 'A'
        )
),

PRIORIZED_CONTRACTS AS (
    SELECT DISTINCT -- noqa
        COALESCE(F64.LRAN8, G.CSSHAN) AS SOURCE_ADDRESS,
        TRIM(G.CSSHAN) AS FARM_ADDRESS_ORIGINAL,
        COALESCE(AN.MAPA8, F64.LRAN8, G.CSSHAN) AS MASTER_ADDRESS,
        TRIM(G.CSMCU) AS BP_DESTINATION,
        BP.LOCATION_UNIT_ID AS UNIT_DESTINATION,
        TRIM(G.CSDMCT) AS CONTRACTNUMBER,
        TRIM(X.HSFRTH) AS OPERATION_TYPE,
        ROW_NUMBER() OVER (
            PARTITION BY
                FARM_ADDRESS_ORIGINAL, BP_DESTINATION, OPERATION_TYPE
            ORDER BY
                CASE
                    WHEN X.HSZ55TPCP = 'FXR' THEN 1
                    WHEN X.HSZ55TPCP = 'FXD' THEN 2
                    WHEN X.HSZ55TPCP IN ('NPE', 'COMP') THEN 3
                    ELSE 99
                END,
            X.HSZ55DTIE,  -- DATA_INICIO_ENTREGA
            TRIM(G.CSDMCT)
        ) AS CONTRACT_PRIORITY_1,
        ROW_NUMBER() OVER (
            PARTITION BY MASTER_ADDRESS, UNIT_DESTINATION, OPERATION_TYPE
            ORDER BY
                CASE
                    WHEN X.HSZ55TPCP = 'FXR' THEN 1
                    WHEN X.HSZ55TPCP = 'FXD' THEN 2
                    WHEN X.HSZ55TPCP IN ('NPE', 'COMP') THEN 3
                    ELSE 99
                END,
            X.HSZ55DTIE,  -- DATA_INICIO_ENTREGA
            TRIM(G.CSDMCT)
        ) AS CONTRACT_PRIORITY_2
    FROM {{ source('jde', 'F5543050') }} AS G
    INNER JOIN {{ source('jde', 'F5543051') }} AS X
        ON
            G.CSKCO = X.HSKCO
            AND G.CSZ55SLPN = X.HSZ55SLPN
            AND G.CSZ55SLPT = X.HSZ55SLPT
            AND G.CSZ55SLPS = X.HSZ55SLPS
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS BP
        ON TRIM(G.CSMCU) = BP.LOCATIONID
    INNER JOIN {{ source('jde', 'F38010') }} AS Y
        ON
            G.CSDMCT = Y.DNDMCT
            AND TRIM(Y.DNDMSC) = 'A'
    LEFT JOIN {{ source('jde', 'F5543064') }} AS F64
            ON
                G.CSKCO = F64.LRKCO
                AND G.CSZ55SLPN = F64.LRZ55SLPN
                AND G.CSZ55SLPT = F64.LRZ55SLPT
    INNER JOIN F4311_CTE AS F43
        ON TRIM(G.CSDMCT) = TRIM(F43.PDDMCT)
    LEFT JOIN {{ source('jde', 'F0150') }} AS AN
        ON COALESCE(F64.LRAN8, G.CSSHAN) = AN.MAAN8
    INNER JOIN VALID_CONTRACTS AS CC
        ON CC.CONTRACTNUMBER = TRIM(G.CSDMCT)
    WHERE
        1 = 1
        AND TRY_CAST(G.CSZ55SLPT AS BIGINT) = 12
        AND G.CSKCO IN ('52171', '52191', '52180')
        AND G.CSZ55SLPS = 'E' -- SLIP EFETIVADO
        AND TRIM(Y.DNDMCT) != ''
        --AND X.HSFRTH IN ('CIF', 'FOB')
    -- QUALIFY CONTRACT_PRIORITY = 1
),

TAB_OH_GLOBAL AS (
    SELECT
        F5543220.RTKCOO, F5543220.RTDCTO, F5543220.RTSFXO, F5543220.RTDOCO,
        F5543220.RTLDNM, F5543220.RTLOTN, F5543220.RTQ720708,
        F5543220.RTBBRCD, F5543220.RTSTR02, F5543220.RTVMCU, F5543220.RTLNID,
        F5543051.HSFRTH, F5543220.RTGKCOO, F5543220.RTGDCTO, F5543220.RTGLNID,
        CASE
            WHEN F5543220.RTGDOCO = 0 AND F5543051.HSFRTH = 'CIF'
                THEN 0
        ELSE F5543220.RTUKID
        END AS RTUKID,
        CASE
            WHEN F5543220.RTGDOCO = 0 AND F5543051.HSFRTH = 'CIF'
                THEN F5543220.RTDOCO
        ELSE F5543220.RTGDOCO
        END RTGDOCO,
        CASE
            WHEN F5543220.RTISSD = 0
                THEN F5543220.RTISSU
            ELSE F5543220.RTISSD
        END RTISSD,
        CASE
            WHEN F5543220.RTGDOCO = 0
                THEN SUM(F5543220.RTQT03) - SUM(F5543220.RTUREC)
            ELSE SUM(F5543220.RTUREC)
        END AS RTUREC,
        SUM(F5543220.RTQT03) AS RTQT03
    FROM {{ source('jde', 'F5543220') }} AS F5543220
    INNER JOIN {{ source('jde', 'F5543050') }} AS F5543050
        ON F5543220.RTDMT1 = F5543050.CSDMCT
    INNER JOIN {{ source('jde', 'F5543051') }} AS F5543051
        ON
            F5543050.CSKCO = F5543051.HSKCO
            AND F5543050.CSZ55SLPN = F5543051.HSZ55SLPN
            AND F5543050.CSZ55SLPT = F5543051.HSZ55SLPT
            AND F5543050.CSZ55SLPS = F5543051.HSZ55SLPS
    LEFT JOIN UDC AS UDC_DESATIVA
        ON
            UDC_DESATIVA.CATEGORY = 'SOURCING CONTRACT'
            AND UDC_DESATIVA.STAGE = 'DESATIVA OH GLOBAL'
            AND TRIM(UDC_DESATIVA.SOURCE_CODE) = TRIM(F5543220.RTDMT1)
    WHERE
        1 = 1
        AND F5543220.RTTRDJ >= 124306
        AND F5543220.RTFLAG IN ('A', 'G')
        AND TRIM(F5543050.CSDMCT) != ''
        -- AND F5543220.RTGDOCO != 0
        AND TRIM(F5543051.HSFRTH) NOT IN ('CIF', '')
        AND UDC_DESATIVA.SOURCE_CODE IS NULL
        AND {{ filter_remove_jde_delete_data('F5543220') }}
        AND {{ filter_remove_jde_delete_data('F5543050') }}
        AND {{ filter_remove_jde_delete_data('F5543051') }}
    GROUP BY
        F5543220.RTKCOO, F5543220.RTDCTO, F5543220.RTSFXO,
        F5543220.RTDOCO, F5543220.RTLDNM, F5543220.RTLOTN, F5543220.RTUKID,
        F5543220.RTGDOCO, F5543220.RTISSD, F5543220.RTQ720708,
        F5543220.RTBBRCD, F5543220.RTISSU, F5543220.RTSTR02,
        F5543220.RTVMCU, F5543220.RTLNID, F5543051.HSFRTH,
        F5543220.RTGKCOO, F5543220.RTGDCTO, F5543220.RTGLNID
),

F564310A AS (
    SELECT
        T11.TNKCOO,
        T11.TNDOCO,
        T11.TNDCTO,
        T11.TNURRF,
        COALESCE(ROUND(UDC_RECUSA_FBZ.TARGET_CODE, 0), T11.TNLDNM) AS TNLDNM
    FROM {{ source('jde', 'F564310A') }} AS T11
    LEFT JOIN UDC AS UDC_RECUSA_FBZ
        ON
            UDC_RECUSA_FBZ.CATEGORY = 'SHIPMENT'
            AND UDC_RECUSA_FBZ.STAGE = 'RECUSA_FBZ'
            AND TRIM(T11.TNLDNM) = TRIM(UDC_RECUSA_FBZ.SOURCE_CODE)
    WHERE
        1 = 1
        AND {{ filter_remove_jde_delete_data('T11') }}
),

F5549300_CTE AS (
    SELECT
        T4.CFKCOO,
        T4.CFDOCO,
        T4.CFDCTO,
        T4.CFLNID,
        T4.CFANCR,
        T4.CFAN8
    FROM {{ source('jde', 'F5549300') }} AS T4
    WHERE
        1 = 1
        AND TRIM(T4.CFURCD) != 'C'
        AND T4.CFANCR > 0
        AND {{ filter_remove_jde_delete_data('T4') }}
    QUALIFY RANK() OVER (
        PARTITION BY T4.CFKCOO, T4.CFDOCO, T4.CFDCTO
        ORDER BY T4.CFLNID ASC
    ) = 1
),

PURCHASE_STATUS AS (
    -- Query para listar Fichas aplicadas a um contrato status 450/460 e 460/999
    SELECT DISTINCT
        CASE
            WHEN T19.HSFRTH = 'CIF' THEN 'CIF'
            WHEN
                T11.TNLDNM > 0 AND (
                    SELECT COUNT(F4960.TMLDNM)
                    FROM {{ source('jde', 'F4960') }} AS F4960
                    LEFT JOIN {{ source('jde', 'F4311') }} AS F4311
                        ON
                            F4960.TMLDNM = F4311.PDURAB
                            AND {{ filter_remove_jde_delete_data('F4311') }}
                            AND F4311.PDDCTO NOT IN ('TR', 'OR', 'OH')
                            AND NOT (
                                F4311.PDLTTR = '980' AND F4311.PDNXTR = '999'
                            )
                    WHERE
                        F4960.TMLDNM = T11.TNLDNM
                        --AND F4960.TMLDLS = '98'
                        AND (F4960.TMLDLS != '98' AND F4960.TMLOAD >= 124000)
                        AND {{ filter_remove_jde_delete_data('F4960') }}
                ) > 0
                THEN 'FBZ'
            WHEN
                T19.RTLDNM > 0 AND (
                    SELECT COUNT(F4960.TMLDNM)
                    FROM {{ source('jde', 'F4960') }} AS F4960
                    LEFT JOIN {{ source('jde', 'F4311') }} AS F4311
                        ON
                            F4960.TMLDNM = F4311.PDURAB
                            AND {{ filter_remove_jde_delete_data('F4311') }}
                            AND F4311.PDDCTO NOT IN ('TR', 'OR', 'OH')
                            AND NOT (
                                F4311.PDLTTR = '980' AND F4311.PDNXTR = '999'
                            )
                    WHERE
                        F4960.TMLDNM = T19.RTLDNM
                        --AND F4960.TMLDLS = '98'
                        AND (F4960.TMLDLS != '98' AND F4960.TMLOAD >= 124000)
                        AND {{ filter_remove_jde_delete_data('F4960') }}
                ) > 0
                THEN 'FBZ'
            WHEN T4.CFDOCO > 0 THEN 'FOB'
            WHEN TRIM(T1.PHFRTH) != '' THEN T1.PHFRTH
            ELSE 'CIF'
        END AS OPERATION_TYPE,
        CASE
            -- SE FOR OH GLOBAL, DEFINIR O RTLOTN COMO FARM_ADDRESS
            -- WHEN T19.RTLOTN IS NOT NULL
            --     THEN T19.RTLOTN
            -- QUANDO A FICHA POSSUIR LOCAL DE COLETA NA F5549300
            -- UTILIZAR ESSE DADO COMO ORIGEM.
            WHEN T4.CFAN8 > 0
                THEN T4.CFAN8
            ELSE
                CASE
                    -- QUANDO A FICHA POSSUIR CONTRATO ASSOCIADO E HOUVER LOCAL
                    -- DE COLETA INFORMADO PARA ELE USAR ESSE DADO COMO ORIGEM
                    WHEN T7.LRAN8 > 0 THEN T7.LRAN8
                    -- SE NAO HOUVER LOCAL DE COLETA INFORMADO NAS 2 SITUACOES
                    -- ACIMA, UTILIZAR A INFORMACAO DA FAZENDA COMO ORIGEM
                    ELSE
                        CASE
                            WHEN T6.CSSHAN > 0 THEN T6.CSSHAN
                            ELSE T0.PDAN8
                        END
                END
        END AS FARM_ADDRESS,
        TRIM(T0.PDAN8) AS FARM_ADDRESS_ORIGINAL,
        TRIM(T0.PDANBY) AS ADDRESS_PRODUTOR,
        CASE
            WHEN TRIM(T6.CSEMCU) != '' THEN TRIM(T6.CSEMCU)
            ELSE TRIM(T1.PHMCU)
        END AS NEGOTIATION_BRANCH_PLANT,
        T0.PDSHAN AS ADDRESS_DESTINATION,
        TRIM(T0.PDMCU) AS BRANCH_PLANT_DESTINATION,
        IFF(
            T19.RTUKID IS NOT NULL,
            TRUNC(T19.RTGDOCO),
            TRUNC(T0.PDDOCO)
        ) AS PURCHASE_CODE,
        COALESCE(T19.RTUKID, T0.PDLNID) AS ID_OH_GLOBAL,
        T0.PDLNID AS LINENUMBER,
        -- COALESCE(TRUNC(T19.RTGDOCO), TRUNC(T0.PDDOCO)) AS PURCHASE_CODE,
        CONCAT(T0.PDLTTR, '-', T0.PDNXTR) AS PURCHASE_STATUS_CODE,
        CASE
            WHEN T0.PDNXTR = '420' THEN 'Ficha Criada'
            WHEN T0.PDLTTR = '980' THEN 'Ficha Cancelada'
            WHEN T0.PDNXTR IN ('460', '999') THEN 'Ficha Aplicada'
        END AS PURCHASE_STATUS,
        CASE
            WHEN CONCAT(T0.PDLTTR, '-', T0.PDNXTR) = '980-999'
                THEN NULL
            ELSE
                NULLIF(
                    REGEXP_REPLACE(UPPER(TRIM(T0.PDDMCT)), '[^A-Z0-9]', ''),
                    ''
                )
        END AS ORIGINATION_CONTRACT,
        CASE
            -- CASO MUDAR A REGRA DO CARRIER ADDRESS SE ATENTAR NO ABAIXO
            -- DA TRANSPORTADORA 37094442
            WHEN T4.CFANCR = 37094442
                THEN 'FER'
            WHEN T4.CFANCR = 37177911
                THEN 'FER'
            WHEN COALESCE(T4.CFANCR, 0) = 0 AND T0.PDANCR = 37094442
                THEN 'FER'
            WHEN TRIM(LOWER(T14.DRDL01)) in ('rodoviário','rodoviÁrio')
                THEN 'ROD'
            WHEN TRIM(LOWER(T14.DRDL01)) in ('ferroriário','ferroviÁrio')
                THEN 'FER'
            WHEN TRIM(LOWER(T14.DRDL01)) in ('hidroviário','hidroviÁrio')
                THEN 'HID'
            WHEN TRIM(LOWER(T14.DRDL01)) in ('marítimo','marÍtimo')
                THEN 'HID'
            WHEN TRIM(LOWER(T14.DRDL01)) in ('fluvial')
                THEN 'HID'
            WHEN LENGTH(TRIM(TRANSLATE(T1.PHDESC,' -', ''))) = 7
                THEN 'ROD'
            WHEN LENGTH(TRIM(TRANSLATE(T1.PHDESC,' -', ''))) IN (10, 11)
                THEN 'FER'
            ELSE 'ROD'
        END MODAL,
        CASE
            WHEN T4.CFANCR > 0 THEN TO_CHAR(T4.CFANCR)
            WHEN T0.PDANCR > 0 THEN TO_CHAR(T0.PDANCR)
            -- ELSE '00000000'
        END AS CARRIER_ADDRESS,
        CASE
            WHEN COALESCE(T4.CFANCR, -1) > 0 THEN TRIM(T17.ABALPH)
            WHEN TRIM(T12.ABALPH) IS NOT NULL THEN TRIM(T12.ABALPH)
        END AS CARRIER_NAME,
        UPPER(TRIM(TRANSLATE(T1.PHDESC, ' -', ''))) AS PLATE,
        CASE
            WHEN (T19.RTISSD != 0 AND T19.RTISSD IS NOT NULL)
                THEN {{ julian_date_to_gregorian('T19', 'RTISSD') }}
            WHEN (T0.PDTRDJ != 0 AND T0.PDTRDJ IS NOT NULL)
                THEN {{ julian_date_to_gregorian('T0', 'PDTRDJ') }}
            ELSE NULL
        /*
            420/480 - DATA CARREGAMENTO;
            460/999 DATA CRIACAO FICHA;
        */
        END AS PURCHASE_DATE,
        TRIM(T0.PDLITM) AS PRODUCT_CODE,
        CASE
            WHEN COALESCE(TRY_CAST(T19.RTUREC AS BIGINT), 0) > 0
                THEN T19.RTUREC::BIGINT / 1000
            WHEN T5.QSUORG::BIGINT > 0
                THEN T5.QSUORG::BIGINT / 1000
            ELSE T0.PDUORG::BIGINT / 1000
        END TRANSPORTED_VOLUME,
        T0.PDUOM AS UM_PRODUCT,
        -- TRIM(T0.PDCRCD) AS CURRENCY,
        'BRE' AS CURRENCY,
        CASE
            WHEN (
                T19.RTGDOCO IS NOT NULL
                AND T25.FDISSU != 0
                AND T25.FDISSU IS NOT NULL
            )
                THEN {{ julian_date_to_gregorian('T25', 'FDISSU') }}
            WHEN (T18.NFISSU != 0 AND T18.NFISSU IS NOT NULL)
                THEN {{ julian_date_to_gregorian('T18', 'NFISSU') }}
            ELSE {{ julian_date_to_gregorian('T0', 'PDTRDJ') }}
        END AS INVOICE_ISSUANCE_DATE,
        CASE
            WHEN T0.PDDGL != 0  AND T0.PDDGL IS NOT NULL
                THEN  {{ julian_date_to_gregorian('T0', 'PDDGL') }}
            ELSE NULL
        END AS PURCHASE_APPLICATION_DATE,
        T0.PDVR02 AS LOT_ID,
        ROUND(
            CASE
                WHEN NVL(T19.RTQT03::BIGINT, 0) > 0
                    THEN T0.PDUORG * (T19.RTUREC / T19.RTQT03) / 1000
                ELSE T0.PDUORG/ 1000
            END, 0
        ) AS INVOICE_VOLUME,
        ROUND(
            CASE
                WHEN NVL(T19.RTQT03::BIGINT, 0) > 0 AND T19.HSFRTH = 'CIF'
                    THEN T19.RTUREC / 1000
                WHEN NVL(T19.RTQT03::BIGINT, 0) > 0
                    THEN T19.RTUREC / 1000
                    -- THEN T0.PDUREC * (T19.RTUREC / T19.RTQT03) / 1000
                WHEN T1.PHURCD = 'PO'
                    THEN T0.PDUORG::BIGINT / 1000
                ELSE T0.PDUREC::BIGINT / 1000
            END, 0
        ) AS APPLIED_VOLUME,
        T0.PDKCOO AS COMPANY,
        COALESCE(
            -- Case the num_nf equal zero, get from chave nfe
            CASE
                WHEN TRUNC(T19.RTQ720708) = 0
                    THEN SUBSTR(NULLIF(T19.RTBBRCD, '')::STRING, 30, 5)::BIGINT
                ELSE TRUNC(T19.RTQ720708)
            END,
            CASE
                WHEN TRUNC(T18.NFNFENUDF) = 0
                    THEN NULL
                ELSE TRUNC(T18.NFNFENUDF)
            END,
            TRUNC(T18.NFBNNF),
            0
        )::STRING AS NUM_NF,
        CASE
            WHEN TRIM(T19.RTBBRCD) != '' THEN TRIM(T19.RTBBRCD)
            WHEN TRIM(T18.NFBBRCD) = '' THEN NULL
            ELSE TRIM(T18.NFBBRCD)
        END CHAVE_NF,
        COALESCE(T19.RTSTR02, T18.NFNFEBSER, '0') AS INVOICE_SERIES,
        CASE
            WHEN
                COALESCE(T19.RTLDNM, 0) > 0 AND T19.HSFRTH != 'CIF'
                THEN T19.RTLDNM
            WHEN
                T11.TNLDNM > 0
                AND (
                    SELECT COUNT(F4960.TMLDNM)
                    FROM {{ source('jde', 'F4960') }} AS F4960
                    LEFT JOIN {{ source('jde', 'F4311') }} AS F4311
                        ON
                            F4960.TMLDNM = F4311.PDURAB
                            AND {{ filter_remove_jde_delete_data('F4311') }}
                            AND F4311.PDDCTO NOT IN ('TR', 'OR', 'OH')
                            AND NOT (
                                F4311.PDLTTR = '980' AND F4311.PDNXTR = '999'
                            )
                    WHERE
                        F4960.TMLDNM = T11.TNLDNM
                        --AND F4960.TMLDLS = '98'
                        AND (F4960.TMLDLS != '98' AND F4960.TMLOAD >= 124000)
                        AND {{ filter_remove_jde_delete_data('F4960') }}
                ) > 0
                AND (T0.PDLTTR || '-' || T0.PDNXTR) != '980-999'
                THEN T11.TNLDNM
        END AS LOAD_NUMBER,
        -- UDC OPERACOES TRANSFERENCIA
        CASE
            WHEN T21.CTEV02 IS NOT NULL AND TRIM(T22.DRSPHD) = 'TRF'
                THEN NULL
            WHEN T21.CTEV02 IS NOT NULL
                THEN TRIM(T22.DRSPHD)
            WHEN
                (UDC.DRKY IS NULL OR UDC.DRKY = ' ')
                AND NOT T11.TNURRF IS NULL
                AND COALESCE(T19.RTLDNM, 0) = 0
                THEN 'VEN'
        END AS OPERATION_TYPE_FBZ,
        T19.RTDOCO AS OH_GLOBAL,
        T20.HSFRTH AS OPERATION_TYPE_CTR,
        IFF(
            COALESCE(TRY_CAST(PDCNDJ AS BIGINT), 0) = 0,
            NULL,
            {{ julian_date_to_gregorian('T0', 'PDCNDJ') }}
        ) AS CANCELLATION_DATE,
        CASE
            WHEN (
                T23.PDLNTY != 'S3'
                OR (T23.PDLNTY = 'S3' AND T20.HSZ55TPCP = 'UNP')
                OR T24.SALTYI IS NOT NULL
            ) THEN 'PRICED'
            WHEN T23.PDLNTY = 'S3' AND T24.SALTYI IS NULL THEN 'PAF'
        END AS PRICETYPE,
        TRIM(T13.ABTAX) AS SOURCE_CNPJ,
        FINALDESTINATION,
        TRY_CAST(T0.PDOORN AS BIGINT) AS NF_F4311
    /* DADOS DETALHE FICHA */
    FROM {{ source('jde', 'F4311') }} AS T0
    /* DADOS CABEÇALHO FICHA */
    INNER JOIN {{ source('jde', 'F4301') }} AS T1
        ON
            T0.PDKCOO = T1.PHKCOO
            AND T0.PDDOCO = T1.PHDOCO
            AND T0.PDDCTO = T1.PHDCTO
            AND {{ filter_remove_jde_delete_data('T1') }}
    /* DADOS BP FICHA */
    INNER JOIN {{ source('jde', 'F0006') }} AS T3
        ON T0.PDMCU = T3.MCMCU
            AND {{ filter_remove_jde_delete_data('T3') }}
    /* DADOS FICHA ENVIO x CTMS */
    LEFT JOIN F5549300_CTE AS T4
        ON
            T0.PDKCOO = T4.CFKCOO
            AND T0.PDDOCO = T4.CFDOCO
            AND T0.PDDCTO = T4.CFDCTO
    /* DADOS PESAGEM ORIGEM */
    LEFT JOIN {{ source('jde', 'F5549001') }} AS T5
        ON
            T0.PDKCOO = T5.QSKCOO
            AND T0.PDDOCO = T5.QSDOCO
            AND T0.PDDCTO = T5.QSDCTO
            AND T0.PDMCU = T5.QSMCU
            AND {{ filter_remove_jde_delete_data('T5') }}
    /* CONTRATO */
    LEFT JOIN {{ source('jde', 'F5543050') }} AS T6
        ON
            T0.PDDMCT = T6.CSDMCT
            AND T6.CSZ55SLPT = '12'
            AND REPLACE(T6.CSDMCT, ' ') != ''
            AND {{ filter_remove_jde_delete_data('T6') }}
    /* LOCAL DE COLETA DO SLIP DO CONTRATO */
    LEFT JOIN {{ source('jde', 'F5543064') }} AS T7
        ON
            T6.CSKCO = T7.LRKCO
            AND T6.CSZ55SLPT = T7.LRZ55SLPT
            AND T6.CSZ55SLPN = T7.LRZ55SLPN
            AND {{ filter_remove_jde_delete_data('T7') }}
    /* DADOS RELACIONAMENTO FICHA/LOAD FBZ */
    LEFT JOIN F564310A AS T11
        ON
            T0.PDKCOO = T11.TNKCOO
            AND T0.PDDOCO = T11.TNDOCO
            AND T0.PDDCTO = T11.TNDCTO
    /* DADOS TRANSPORTADORA F4311 */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T12
        ON T0.PDANCR = T12.ABAN8
            AND {{ filter_remove_jde_delete_data('T12') }}
    /* DADOS ORIGEM CNPJ F4311 */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T13
        ON
            -- T0.PDANBY = T13.ABAN8
            TRIM(T0.PDAN8) = TRIM(T13.ABAN8)
            AND {{ filter_remove_jde_delete_data('T13') }}
    /* DADOS PLACA */
    LEFT JOIN {{ source('jde', 'F4930') }} AS T15
        ON
            UPPER(TRIM(TRANSLATE(T1.PHDESC,' -',''))) = UPPER(TRIM(TRANSLATE(T15.VMVEHI,' -','')))
            AND {{ filter_remove_jde_delete_data('T15') }}
    /* UDC MODAL */
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T14
        ON
            LPAD(T15.VMURCD, 10, ' ') = T14.DRKY
            AND COALESCE(T14.DRSY,'') = '55BR'
            AND COALESCE(T14.DRRT,'') = 'DM'
            AND {{ filter_remove_jde_delete_data('T14') }}
    /* DADOS TRANSPORTADORA F5549300 */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T17
        ON
            T4.CFANCR = T17.ABAN8
            AND {{ filter_remove_jde_delete_data('T17') }}
    /* DADOS NF */
    LEFT JOIN {{ source('jde', 'F5576201') }} AS T18
        ON
            T0.PDKCOO = T18.NFKCOO
            AND T0.PDDOCO = TRUNC(T18.NFDOCO)::STRING
            AND T0.PDDCTO = T18.NFPDCT
            AND T0.PDITM = TRUNC(T18.NFITM)::STRING
            AND TRUNC(T0.PDLNID::BIGINT / 100) * 100 = TRUNC(T18.NFLNID)
            AND COALESCE(TRUNC(T18.NFN001)::STRING,'') = '0'
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS UDC
        ON
          UDC.DRSY = '55BR'
          AND UDC.DRRT = 'A6'
          AND TRIM(T11.TNURRF)= TRIM(UDC.DRKY)
          AND {{ filter_remove_jde_delete_data('UDC') }}
    -- LEFT JOIN (SELECT * FROM {{ source('jde', 'F5543220') }} where RTTRDJ >= 124306) AS T19
    LEFT JOIN TAB_OH_GLOBAL AS T19
        ON
            T19.RTKCOO = T0.PDKCOO
            AND T19.RTDCTO = T0.PDDCTO
            AND T19.RTSFXO = T0.PDSFXO
            AND T19.RTDOCO::STRING = T0.PDDOCO
            AND T19.RTLNID::STRING = T0.PDLNID
    LEFT JOIN {{ source('jde', 'F7611B') }} AS T25
        ON
            T19.RTGKCOO = T25.FDKCOO
            AND T19.RTGDOCO = TRUNC(T25.FDDOCO)::STRING
            AND T19.RTGDCTO = T25.FDPDCT
            AND T19.RTGLNID = T25.FDLNID
            AND {{ filter_remove_jde_delete_data('T25') }}
    LEFT JOIN {{ source('jde', 'F5543051') }} AS T20
        ON
            T20.HSKCO = T6.CSKCO
            AND T20.HSZ55SLPN = T6.CSZ55SLPN
            AND T20.HSZ55SLPT = T6.CSZ55SLPT
    LEFT JOIN {{ source('jde', 'F5549200') }} AS T21
        ON
            T19.RTVMCU = T21.CTVMCU
            AND T19.RTLDNM = T21.CTLDNM
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T22
        ON
            LPAD(T21.CTEV02, 8, ' ') = RTRIM(T22.DRKY)
            AND T22.DRSY = '55BR'
            AND T22.DRRT = 'M4'
    LEFT JOIN (
        SELECT
            PDRORN, PDRKCO, PDRCTO, PDRLLN, PDLNTY,
            PDDOCO, PDKCOO, PDDCTO, PDLNID, PDSFXO
        FROM {{ source('jde', 'F4311') }} AS F4311
        WHERE
            1 = 1
            AND {{ filter_remove_jde_delete_data('F4311') }}
            AND PDLNTY NOT IN ('DA', 'DF')
            AND PDDCTO IN ('OG', 'O9')
    ) AS T23
        ON
		    T0.PDDOCO = COALESCE(NULLIF(T23.PDRORN, ''), 0)::NUMBER
            AND T0.PDKCOO = T23.PDRKCO
            AND T0.PDDCTO = T23.PDRCTO
            AND T0.PDLNID = T23.PDRLLN
    LEFT JOIN F5543081 AS T24
       ON
            T23.PDDOCO = T24.SADOCO
        AND T23.PDDCTO = T24.SADCTO
        AND T23.PDSFXO = T24.SASFXO
        --AND T23.PDLNID = T24.SALNID
        AND T23.PDKCOO = T24.SAKCOO
        AND COALESCE(NULLIF(T24.SARORN, ''), 0)::NUMBER = T0.PDDOCO
        AND T24.SARCTO = T0.PDDCTO
        AND T24.SARLLN = T0.PDLNID
    LEFT JOIN (
        SELECT SOURCE_CODE, TARGET_CODE AS FINALDESTINATION
        FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
        WHERE TRIM(CATEGORY)='SHIPMENT'
        AND TRIM(STAGE)='CIF FOB TRANSBORDO'
    ) AS UDC_FINALDESTINATION
        ON TRIM(T0.PDMCU) || TRIM(T6.CSAA10) = UDC_FINALDESTINATION.SOURCE_CODE

    WHERE
        1 = 1
        AND T0.PDKCOO IN ('52171', '52191', '52180') -- CIAS -> CASC, AMIDOS, CNH
        AND T0.PDLTTR IN ('980', '400', '450', '460')
        AND T0.PDNXTR IN ('999', '420', '460')
        AND T0.PDTRDJ >= 125000
        AND T0.PDDCTO IN ('OH') -- TIPO DA FICHA
        AND T0.PDLNTY = 'EE' -- SOMENTE LINHA DA MERCADORIA DA FICHA
        AND {{ filter_remove_jde_delete_data('T0') }}
)

SELECT DISTINCT
    FC.OPERATION_TYPE,
    FC.FARM_ADDRESS,
    FC.FARM_ADDRESS_ORIGINAL,
    FC.ADDRESS_PRODUTOR,
    FC.NEGOTIATION_BRANCH_PLANT,
    FC.ADDRESS_DESTINATION,
    FC.BRANCH_PLANT_DESTINATION,
    FC.PURCHASE_CODE,
    FC.ID_OH_GLOBAL,
    FC.PURCHASE_STATUS_CODE,
    FC.PURCHASE_STATUS,
    CASE
        WHEN FC.PURCHASE_STATUS_CODE = '980-999'
            THEN 'N/A'
        WHEN FC.PURCHASE_STATUS_CODE = '400-420'
            THEN COALESCE(
                FC.ORIGINATION_CONTRACT,
                SCHED_C2.CONTRACTNUMBER,
                SCHED_C.CONTRACTNUMBER,
                PRIO_C1.CONTRACTNUMBER,
                PRIO_C2.CONTRACTNUMBER,
                'N/A'
            )
        ELSE FC.ORIGINATION_CONTRACT
    END AS ORIGINATION_CONTRACT,
    FC.MODAL,
    FC.CARRIER_ADDRESS,
    FC.CARRIER_NAME,
    FC.PLATE,
    FC.PURCHASE_DATE,
    FC.PRODUCT_CODE,
    FC.TRANSPORTED_VOLUME,
    FC.UM_PRODUCT,
    FC.CURRENCY,
    FC.INVOICE_ISSUANCE_DATE,
    IFF(
        FC.PURCHASE_STATUS_CODE IN ('980-999', '400-420'),
        NULL,
        FC.PURCHASE_APPLICATION_DATE
    ) AS PURCHASE_APPLICATION_DATE,
    FC.LOT_ID,
    FC.INVOICE_VOLUME,
    FC.APPLIED_VOLUME,
    FC.COMPANY,
    FC.NUM_NF,
    FC.CHAVE_NF,
    MAX(FC.INVOICE_SERIES) AS INVOICE_SERIES,
    CASE
        WHEN FC.OPERATION_TYPE = 'CIF' AND FC.OH_GLOBAL IS NOT NULL
            THEN NULL
        ELSE FC.LOAD_NUMBER
    END AS LOAD_NUMBER,
    FC.OPERATION_TYPE_FBZ,
    FC.OH_GLOBAL,
    FC.OPERATION_TYPE_CTR,
    FC.CANCELLATION_DATE,
    FC.PRICETYPE,
    FC.SOURCE_CNPJ,
    MAX(
        COALESCE(
            FC.FINALDESTINATION,
            FINAL_OHGLOBAL.LOCATIONID,
            FINAL_C.LOCATIONID,
            FINAL_C2.LOCATIONID,
            BP.LOCATION_TO
        )
    ) AS FINALDESTINATION,
    FC.NF_F4311,
    FC.LINENUMBER,
    COALESCE(
        FINAL_OHGLOBAL.DEST,
        FINAL_C.DEST,
        FINAL_C2.DEST,
        'N/A'
    ) AS DESTINATION_CODE
FROM PURCHASE_STATUS AS FC
LEFT JOIN BP
    ON FC.BRANCH_PLANT_DESTINATION = BP.LOCATION_FROM
LEFT JOIN {{ ref('tab_shipment_finaldestination_contract_stg') }} AS FINAL_C
    ON
        FINAL_C.CONTRACTNUMBER = FC.ORIGINATION_CONTRACT
        AND FINAL_C.FICHA = FC.PURCHASE_CODE
        AND FINAL_C.LINENUMBER = FC.LINENUMBER
LEFT JOIN {{ ref('tab_shipment_finaldestination_contract_stg') }} AS FINAL_C2
    ON
        FINAL_C2.CONTRACTNUMBER = FC.ORIGINATION_CONTRACT
        AND FINAL_C2.FICHA = 0
LEFT JOIN {{ ref('tab_shipment_finaldestination_contract_stg') }} AS FINAL_OHGLOBAL
    ON
        FINAL_OHGLOBAL.CONTRACTNUMBER = FC.ORIGINATION_CONTRACT
        AND FINAL_OHGLOBAL.FICHA = FC.OH_GLOBAL
LEFT JOIN SCHEDULED_CONTRACTS AS SCHED_C
    ON
        FC.FARM_ADDRESS = SCHED_C.SOURCE
        AND FC.BRANCH_PLANT_DESTINATION = SCHED_C.DESTINATION
        AND FC.ADDRESS_PRODUTOR = SCHED_C.ADDRESS_PRODUTOR
        AND SCHED_C.PRIORITY_1 = 1
LEFT JOIN SCHEDULED_CONTRACTS AS SCHED_C2
    ON
        FC.BRANCH_PLANT_DESTINATION = SCHED_C2.DESTINATION
        AND FC.ADDRESS_PRODUTOR = SCHED_C2.ADDRESS_PRODUTOR
        AND SCHED_C2.PRIORITY_2 = 1
INNER JOIN {{ ref('tab_location_internal_stg') }} AS BP_STR
        ON FC.BRANCH_PLANT_DESTINATION = BP_STR.LOCATIONID
LEFT JOIN {{ source('jde', 'F0150') }} AS AN
        ON
            FC.FARM_ADDRESS = AN.MAAN8
            AND {{ filter_remove_jde_delete_data('AN') }}
LEFT JOIN PRIORIZED_CONTRACTS AS PRIO_C1
    ON
        FC.FARM_ADDRESS_ORIGINAL = PRIO_C1.FARM_ADDRESS_ORIGINAL
        AND FC.BRANCH_PLANT_DESTINATION = PRIO_C1.BP_DESTINATION
        AND FC.OPERATION_TYPE = PRIO_C1.OPERATION_TYPE
        AND PRIO_C1.CONTRACT_PRIORITY_1 = 1
LEFT JOIN PRIORIZED_CONTRACTS AS PRIO_C2
    ON
        COALESCE(AN.MAPA8, FC.FARM_ADDRESS) = PRIO_C2.MASTER_ADDRESS
        AND BP_STR.LOCATION_UNIT_ID = PRIO_C2.UNIT_DESTINATION
        AND FC.OPERATION_TYPE = PRIO_C2.OPERATION_TYPE
        AND PRIO_C2.CONTRACT_PRIORITY_2 = 1
WHERE
    1 = 1
    AND FC.PURCHASE_CODE != 0
GROUP BY
    FC.OPERATION_TYPE,
    FC.FARM_ADDRESS,
    FC.FARM_ADDRESS_ORIGINAL,
    FC.ADDRESS_PRODUTOR,
    FC.NEGOTIATION_BRANCH_PLANT,
    FC.ADDRESS_DESTINATION,
    FC.BRANCH_PLANT_DESTINATION,
    FC.PURCHASE_CODE,
    FC.ID_OH_GLOBAL,
    FC.PURCHASE_STATUS_CODE,
    FC.PURCHASE_STATUS,
    CASE
        WHEN FC.PURCHASE_STATUS_CODE = '980-999'
            THEN 'N/A'
        WHEN FC.PURCHASE_STATUS_CODE = '400-420'
            THEN COALESCE(
                FC.ORIGINATION_CONTRACT,
                SCHED_C2.CONTRACTNUMBER,
                SCHED_C.CONTRACTNUMBER,
                PRIO_C1.CONTRACTNUMBER,
                PRIO_C2.CONTRACTNUMBER,
                'N/A'
            )
        ELSE FC.ORIGINATION_CONTRACT
    END,
    FC.MODAL,
    FC.CARRIER_ADDRESS,
    FC.CARRIER_NAME,
    FC.PLATE,
    FC.PURCHASE_DATE,
    FC.PRODUCT_CODE,
    FC.TRANSPORTED_VOLUME,
    FC.UM_PRODUCT,
    FC.CURRENCY,
    FC.INVOICE_ISSUANCE_DATE,
    IFF(
        FC.PURCHASE_STATUS_CODE IN ('980-999', '400-420'),
        NULL,
        FC.PURCHASE_APPLICATION_DATE
    ),
    FC.LOT_ID,
    FC.INVOICE_VOLUME,
    FC.APPLIED_VOLUME,
    FC.COMPANY,
    FC.NUM_NF,
    FC.CHAVE_NF,
    CASE
        WHEN FC.OPERATION_TYPE = 'CIF' AND FC.OH_GLOBAL IS NOT NULL
            THEN NULL
        ELSE FC.LOAD_NUMBER
    END,
    FC.OPERATION_TYPE_FBZ,
    FC.OH_GLOBAL,
    FC.OPERATION_TYPE_CTR,
    FC.CANCELLATION_DATE,
    FC.PRICETYPE,
    FC.SOURCE_CNPJ,
    FC.NF_F4311,
    FC.LINENUMBER,
    COALESCE(
        FINAL_OHGLOBAL.DEST,
        FINAL_C.DEST,
        FINAL_C2.DEST,
        'N/A'
    )
