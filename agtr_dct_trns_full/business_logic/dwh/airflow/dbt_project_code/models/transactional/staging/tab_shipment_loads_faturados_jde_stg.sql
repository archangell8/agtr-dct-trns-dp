-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}

WITH
UDC AS ( --noqa
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

NOTA_GLOBAL_1 AS (
    SELECT
        DISTINCT
            COALESCE(ROUND(UDC_RECUSA_FBZ.TARGET_CODE, 0), F564310A.TNLDNM)
                AS LOADNUMBER,
            'FBZ' AS OPERATION_TYPE,
            1 AS RATEIO
    FROM {{ source('jde', 'F4311') }} AS F4311
    INNER JOIN {{ source('jde', 'F564310A') }} AS F564310A
        ON
            F4311.PDKCOO = F564310A.TNKCOO
            AND F4311.PDDOCO = F564310A.TNDOCO
            AND F4311.PDDCTO = F564310A.TNDCTO
    LEFT JOIN UDC AS UDC_RECUSA_FBZ
        ON
            UDC_RECUSA_FBZ.CATEGORY = 'SHIPMENT'
            AND UDC_RECUSA_FBZ.STAGE = 'RECUSA_FBZ'
            AND TRIM(F564310A.TNLDNM) = TRIM(UDC_RECUSA_FBZ.SOURCE_CODE)
    WHERE
        1 = 1
        AND CONCAT(F4311.PDLTTR, '-', F4311.PDNXTR) != '980-999'
        AND {{ filter_remove_jde_delete_data('F4311') }}
        AND {{ filter_remove_jde_delete_data('F564310A') }}
),

NOTA_GLOBAL_2 AS (
    SELECT
        DISTINCT
            F5543220.RTLDNM AS LOADNUMBER,
            F5543051.HSFRTH AS OPERATION_TYPE,
            (
                SUM(F5543220.RTUREC::DECIMAL(20,5)) /
                MAX(
                    DECODE(
                        NVL(F5549001.QSUORG::DECIMAL(20,5), 0),
                        0,
                        F5543220.RTUREC::DECIMAL(20,5),
                        F5549001.QSUORG::DECIMAL(20,5)
                    )
                )
            ) AS RATEIO
    FROM {{ source('jde', 'F5543220') }} AS F5543220
    INNER JOIN {{ source('jde', 'F5543050') }} AS F5543050
        ON F5543220.RTDMT1 = F5543050.CSDMCT
    INNER JOIN {{ source('jde', 'F5543051') }} AS F5543051
        ON
            F5543050.CSKCO = F5543051.HSKCO
            AND F5543050.CSZ55SLPN = F5543051.HSZ55SLPN
            AND F5543050.CSZ55SLPT = F5543051.HSZ55SLPT
            AND F5543050.CSZ55SLPS = F5543051.HSZ55SLPS
    LEFT JOIN {{ source('jde', 'F5549001') }} AS F5549001
        ON
            TO_CHAR(F5549001.QSDOCO) = TO_CHAR(F5543220.RTLDNM)
            AND NOT F5549001.QSDCTO LIKE 'O%'
    WHERE
        1 = 1
        AND F5543220.RTTRDJ >= 124306
        AND F5543220.RTFLAG IN ('A', 'G')
        AND TRIM(F5543050.CSDMCT) != ''
        AND  F5543220.RTLDNM != 0
        --AND F5543220.RTGDOCO != 0
        AND F5543051.HSFRTH != 'CIF'
        AND {{ filter_remove_jde_delete_data('F5543220') }}
        AND {{ filter_remove_jde_delete_data('F5543050') }}
        AND {{ filter_remove_jde_delete_data('F5543051') }}
        AND {{ filter_remove_jde_delete_data('F5549001') }}
        AND RTTRDJ >= 124306
    GROUP BY
        F5543220.RTLDNM,
        F5543051.HSFRTH
),

NOTA_GLOBAL AS (
    SELECT
        LOADNUMBER,
        OPERATION_TYPE,
        RATEIO
    FROM NOTA_GLOBAL_1

    UNION

    --ONLY RETURN FROM SECOND SELECT IF DOESN'T EXISTS ON FIRST
    SELECT
        N2.LOADNUMBER,
        N2.OPERATION_TYPE,
        N2.RATEIO
    FROM NOTA_GLOBAL_2 AS N2
    LEFT JOIN NOTA_GLOBAL_1 AS N1
        ON N1.LOADNUMBER = N2.LOADNUMBER
    WHERE
        1 = 1
        AND N1.LOADNUMBER IS NULL
),

BP AS (
    SELECT
        L.LOCATIONID AS LOCATION_FROM,
        MAX(LD.LOCATIONID) LOCATION_TO
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }} AS LN
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS L
        ON LN.SOURCE_CODE = L.LOCATION_IBP_ASSET
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LD
        ON
            LN.TARGET_CODE = LD.LOCATION_IBP_ASSET
            AND SUBSTR(L.LOCATIONID, 1, 5) = SUBSTR(LD.LOCATIONID, 1, 5)
    WHERE
        1 = 1
        AND CATEGORY = 'LANE'
        AND STAGE = 'ITEM_LANE_TRANSMODE'
        AND L.LOCATION_UNIT_STRUCTURE IN ('TRANSBORDO', 'PORTO FLUVIAL')
        AND LN.DESCRIPTION != 'VIRTUAL'
        AND L.ISACTIVE='TRUE'
        AND LD.ISACTIVE='TRUE'
        AND LD.LOCATION_UNIT_STRUCTURE IN ('PORTO MARÍTIMO')
    GROUP BY
        L.LOCATIONID
    HAVING COUNT(DISTINCT L.LOCATION_CODE, LD.LOCATION_CODE) = 1
),

LINK_PEDIDOS_LOADS AS (
    SELECT
        QXKCOO,
        QXSLNE,
        QXMCU,
        QXLNID,
        QXDCTO,
        QXLITM,
        QXLDNM::STRING AS QXLDNM,
        QXDOCO,
        DECODE(QXSLNE, 0, QXLNID, QXSLNE) AS DECODE_COLUMN
    FROM {{ source('jde', 'F5549015') }} AS F5549015
    WHERE
        1 = 1
        AND {{ filter_remove_jde_delete_data('F5549015') }}

    UNION ALL

    SELECT
        TDKCOO AS QXKCOO,
        TDLNID AS QXSLNE,
        TDVMCU AS QXMCU,
        TDLNID AS QXLNID,
        TDDCTO AS QXDCTO,
        F4101.IMLITM AS QXLITM,
        TDLDNM AS QXLDNM,
        TDDOCO::INT AS QXDOCO,
        DECODE(TDLNID, 0, TDLNID, TDLNID) AS DECODE_COLUMN
    FROM {{ source('jde', 'F49621') }} AS F49621
    INNER JOIN {{ source('jde', 'F4101') }} AS F4101
        ON F4101.IMITM = F49621.TDITM
    WHERE
        1 = 1
        -- Recupera apenas os dois últimos anos de dados
        AND (
            (
                DATEADD(
                    DAY,
                    SUBSTR((F49621.TDUPMJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                    TO_TIMESTAMP(
                        CONCAT(
                            SUBSTR((F49621.TDUPMJ::INT + 1900000)::STRING, 1, 4),
                            '01',
                            '01'
                        ),
                        'YYYYMMDD'
                    )
                )
            )
            >= DATEADD(YEAR, -2, DATE_TRUNC('YEAR', CURRENT_DATE))
        )
        AND NOT EXISTS (
            SELECT 1 FROM {{ source('jde', 'F5549015') }}
            WHERE
                1 = 1
                AND QXLDNM::STRING = TDLDNM
                AND QXKCOO = TDKCOO
                AND QXDOCO = TDDOCO
                AND QXDCTO = TDDCTO
                AND QXSLNE = TDLNID
                AND {{ filter_remove_jde_delete_data('F5549015') }}
        )
        AND {{ filter_remove_jde_delete_data('F49621') }}
        AND {{ filter_remove_jde_delete_data('F4101') }}
),

CTE_F43199 AS (
    SELECT DISTINCT
        F43199.OLDCTO, F43199.OLMCU, F43199.OLLNID,
        F43199.OLKCOO, TRY_CAST(F43199.OLDOCO AS BIGINT) AS OLDOCO
    FROM {{ source('jde', 'F43199') }} AS F43199
    WHERE
        1 = 1
        AND (
            (
                DATEADD(
                    DAY,
                    SUBSTR((F43199.OLUPMJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                    TO_TIMESTAMP(
                        CONCAT(SUBSTR((F43199.OLUPMJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                        'YYYYMMDD'
                    )
                )
            )
            >= DATEADD(YEAR, -2, DATE_TRUNC('YEAR', CURRENT_DATE))
        )
        AND F43199.OLLNID = 1000
        AND {{ filter_remove_jde_delete_data('F43199') }}
),

CTE_F5549015 AS (
    SELECT
        SUM(F5549015.QXSOQS / 1000) SUM_QXSOQS,
        F5549015.QXLDNM,
        F5549015.QXMCU,
        F5549015.QXLITM
    FROM {{ source('jde', 'F5549015') }} AS F5549015
    WHERE
        1 = 1
        AND (
            (
                DATEADD(
                    DAY,
                    SUBSTR((F5549015.QXUPMJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                    TO_TIMESTAMP(
                        CONCAT(SUBSTR((F5549015.QXUPMJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                        'YYYYMMDD'
                    )
                )
            )
            >= DATEADD(YEAR, -2, DATE_TRUNC('YEAR', CURRENT_DATE))
        )
        AND {{ filter_remove_jde_delete_data('F5549015') }}
    GROUP BY
        F5549015.QXLDNM,
        F5549015.QXMCU,
        F5549015.QXLITM
),

CTE_F554901B AS (
    SELECT
        A.HDLDNM AS LOAD_NUMBER,
        MAX(
            (
                DATEADD(
                    DAY,
                    SUBSTR((A.HDTRDJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                    TO_TIMESTAMP(
                        CONCAT(SUBSTR((A.HDTRDJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                        'YYYYMMDD'
                    )
                )
            )
        ) AS ACTUALSHIPDATE
    FROM {{ source('jde', 'F554901B') }} AS A
    WHERE
        1 = 1
        AND A.HDTRDJ > 0
        AND {{ filter_remove_jde_delete_data('A') }}
    GROUP BY 1
),

CTE_F7611B AS (
    SELECT
        SUM(F7611B.FDUORG::BIGINT / 1000) SUM_FDUORG,
        F7611B.FDN002,
        F7611B.FDDCT,
        F7611B.FDITM,
        F7611B.FDBNNF,
        F7611B.FDBSER
    FROM {{ source('jde', 'F7611B') }} AS F7611B
    WHERE
        1 = 1
        AND {{ filter_remove_jde_delete_data('F7611B') }}
    GROUP BY
        F7611B.FDN002,
        F7611B.FDDCT,
        F7611B.FDITM,
        F7611B.FDBNNF,
        F7611B.FDBSER
),

CTE_F5549401 AS (
    SELECT DISTINCT
        F5549401.VDDL011,
        SUBSTR(F5549401.VDAA10, 3, 1) AS VDAA10
    FROM {{ source('jde', 'F5549401') }} AS F5549401
    WHERE
        1 = 1
),

CTE_F554801A AS (
    SELECT
        A.PLLDNM AS LOAD_NUMBER,
        MAX(
            (
                DATEADD(
                    DAY,
                    SUBSTR((A.PLTRDJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                    TO_TIMESTAMP(
                        CONCAT(SUBSTR((A.PLTRDJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                        'YYYYMMDD'
                    )
                )
            )
        ) AS DATA_RECEPCAO_PORTO
    FROM {{ source('jde', 'F554801A') }} AS A
    WHERE
        1 = 1
        AND A.PLTRDJ > 0
        AND {{ filter_remove_jde_delete_data('A') }}
    GROUP BY 1
),

CTE_F4311 AS (
    SELECT
        F4311.*
    FROM {{ source('jde', 'F4311') }} AS F4311
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LOC
        ON TRIM(F4311.PDMCU) = LOC.LOCATIONID
    WHERE
        1 = 1
        AND LOC.LOCATION_UNIT_STRUCTURE in ('PORTO MARÍTIMO', 'FÁBRICA')
        AND F4311.PDDCTO IN ('O8', 'OJ', 'O7', 'OI')
        AND F4311.PDLOTN LIKE '%/%'
        AND F4311.PDURAB > 1
        AND {{ filter_remove_jde_delete_data('F4311') }}
),

CTE_T102 AS (
    SELECT
        TARGET_CODE AS LOCATIONID,
        SOURCE_CODE AS ADDRESS_NUMBER
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
    WHERE
        CATEGORY = 'SHIPMENT'
        AND STAGE = 'SHIPTO'
        AND "STATUS" = 'ATIVO'
),

LOAD_STAGE AS (
    SELECT
        F4960.TMVMCU, F4960.TMLDLS, F4960.TMLOAD,
        F4960.TMADDJ, F4960.TMLDNM, F4960.TMRLNO,
        F4960.TMPVEH, F4960.TMCARS,
        LPL.QXLDNM, LPL.QXLITM, LPL.QXDCTO,
        LPL.QXDOCO, LPL.QXKCOO, LPL.QXMCU,
        LPL.QXLNID, LPL.QXSLNE,
        F4211.SDUOM, F4211.SDDCTO, F4211.SDLNTY,
        F4211.SDLITM, F4211.SDDOCO, F4211.SDRCTO,
        F4211.SDTRDJ, F4211.SDCRCD, F4211.SDSHAN,
        F4211.SDSRP2, F4211.SDRKCO, F4211.SDFRTH,
        F4211.SDKCOO, F4211.SDLNID, F4211.SDDRQJ,
        TRY_CAST(TRIM(F4211.SDRORN) AS BIGINT) AS SDRORN, F4211.SDSRP1,
        F4201.SHURAT, F4201.SHDCTO, F4201.SHMCU,
        F4201.SHKCOO, F4201.SHDOCO,
        F4930.VMURCD, F4930.VMVEHI,
        F0005.DRDL01, F0005.DRSY, F0005.DRRT, F0005.DRKY,
        F5549100.CMRLNO, F5549100.CMALPH
    FROM {{ source('jde', 'F4960') }} AS F4960
    INNER JOIN LINK_PEDIDOS_LOADS AS LPL
        ON
            F4960.TMVMCU = LPL.QXMCU
            AND F4960.TMLDNM = LPL.QXLDNM
    INNER JOIN {{ source('jde', 'F4211') }} AS F4211
        ON
            LPL.QXKCOO = F4211.SDKCOO
            AND LPL.QXDOCO::STRING = F4211.SDDOCO::STRING
            AND LPL.QXDCTO = F4211.SDDCTO
            AND LPL.DECODE_COLUMN = F4211.SDLNID
            AND {{ filter_remove_jde_delete_data('F4211') }}
    INNER JOIN {{ source('jde', 'F4201') }} AS F4201
        ON
            LPL.QXKCOO = F4201.SHKCOO
            AND LPL.QXDOCO::STRING = F4201.SHDOCO::STRING
            AND LPL.QXDCTO = F4201.SHDCTO
            AND {{ filter_remove_jde_delete_data('F4201') }}
    /* DADOS VEÍCULO */
    -- INNER JOIN {{ source('jde', 'F4930') }} AS F4930
    LEFT JOIN {{ source('jde', 'F4930') }} AS F4930
        ON
            F4960.TMPVEH = F4930.VMVEHI
            AND {{ filter_remove_jde_delete_data('F4930') }}
    /* UDC MODAL */
    -- INNER JOIN {{ source('jde', 'PRODCTL_F0005') }} AS F0005
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS F0005
        ON
            F0005.DRSY = '55BR'
            AND F0005.DRRT = 'DM'
            AND LPAD(F4930.VMURCD, 10, ' ') = F0005.DRKY
            AND {{ filter_remove_jde_delete_data('F0005') }}
    /* DADOS MOTORISTA */
    -- INNER JOIN {{ source('jde', 'F5549100') }} AS F5549100
    LEFT JOIN {{ source('jde', 'F5549100') }} AS F5549100
        ON
            F4960.TMRLNO = F5549100.CMRLNO
            AND {{ filter_remove_jde_delete_data('F5549100') }}
    WHERE
        1 = 1
        AND EXISTS (
            SELECT 1
            FROM {{ source('jde', 'F0006') }} AS F0006
            WHERE
                1 = 1
                AND F0006.MCCO IN ('52171', '52191', '52180')  -- CIAS DO BRASIL
                AND F0006.MCSTYL = 'BP'
                AND LENGTH(TRIM(F0006.MCMCU)) = 10
                AND {{ filter_remove_jde_delete_data('F0006') }}
                AND F4960.TMVMCU = F0006.MCMCU
        )
        AND F4960.TMLDNM > 0
        AND F4960.TMLOAD >= 125000
        AND F4960.TMLDLS IN ('80', '90', '98') -- STATUS DO LOAD
        AND F4211.SDDCTO != 'SD'
        AND {{ filter_remove_jde_delete_data('F4960') }}
),

LOAD_FINAL AS (
    -- Query para listar dados de Loads no status 80, 90 E 98
    SELECT DISTINCT
        CASE
            WHEN T18.VHFRTH IS NOT NULL THEN TRIM(T19.DRSPHD)
            WHEN T17.CTEV02 IS NOT NULL THEN TRIM(T20.DRSPHD)
            WHEN T6.DRKY IS NOT NULL THEN 'TRF'
            ELSE 'VEN'
        END AS OPERATION_TYPE,
        TRIM(LS.TMVMCU) AS BRANCH_PLANT_SOURCE,
        CASE
            WHEN T18.VHMCU IS NOT NULL THEN TRIM(T18.VHMCU)
            ELSE TRIM(LS.SHMCU)
        END AS NEGOTIATION_BRANCH_PLANT,
        TRUNC(
            TO_CHAR(
            CASE
                WHEN (T16.OESHAN IS NOT NULL) THEN T16.OESHAN
                ELSE LS.SDSHAN
            END
           )
        )::STRING AS ADDRESS_DESTINATION,
        CASE
            WHEN T22.PDMCU IS NOT NULL THEN TRIM(T22.PDMCU)
            ELSE TRIM(T3.OLMCU)
        END AS BRANCH_PLANT_DESTINATION,
        LS.TMLDNM AS LOAD_NUMBER,
        CASE
            WHEN T22.PDLTTR = '980' AND T22.PDNXTR = '999'
                THEN '98'
            ELSE LS.TMLDLS
        END AS LOAD_STATUS_CODE,
        CASE
            WHEN (T22.PDLTTR = '980' AND T22.PDNXTR = '999')
                THEN 'LOAD CANCELADO'
            WHEN LS.TMLDLS = '80' THEN 'LOAD CONFIRMADO'
            WHEN LS.TMLDLS = '90' THEN 'LOAD ENVIADO AO CTMS'
            WHEN LS.TMLDLS = '98' THEN 'LOAD CANCELADO'
        END AS LOAD_STATUS,
        REPLACE(
            REPLACE(TRIM(T18.VHDMCT), '*', ''), '.', ''
        )  AS ORIGINATION_CONTRACT,
        TRIM(LS.DRDL01) AS MODAL,
        CASE
            WHEN T17.CTCPFG = 'S' THEN TO_CHAR(T17.CTANCR)
            ELSE TO_CHAR(LS.TMCARS)
        END AS CARRIER_ADDRESS,
        CASE
            WHEN T17.CTCPFG = 'S' THEN TRIM(T11.ABALPH)
            ELSE TRIM(T12.ABALPH)
        END AS CARRIER_NAME,
        TRIM(LS.TMPVEH) AS PLATE,
        CASE
            WHEN (TRIM(T17.CTALPH) IS NOT NULL AND TRIM(T17.CTALPH) != '')
                THEN TRIM(T17.CTALPH)
            ELSE TRIM(LS.CMALPH)
        END AS DRIVER_NAME,
        CASE
            WHEN LS.TMLOAD::BIGINT > 0 THEN
                (
                    DATEADD(
                        DAY,
                        SUBSTR((LS.TMLOAD::INT + 1900000)::STRING, 5, 3)::INT - 1,
                        TO_TIMESTAMP(
                            CONCAT(SUBSTR((LS.TMLOAD::INT + 1900000)::STRING, 1, 4), '01', '01'),
                            'YYYYMMDD'
                        )
                    )
                )
            ELSE NULL
        END AS SCHEDULED_LOAD_DATE,
        CASE
            WHEN LS.SDDRQJ::BIGINT > 0 THEN
                (
                    DATEADD(
                        DAY,
                        SUBSTR((LS.SDDRQJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                        TO_TIMESTAMP(
                            CONCAT(SUBSTR((LS.SDDRQJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                            'YYYYMMDD'
                        )
                    )
                )
            ELSE NULL
        END AS SCHEDULED_SHIPPING_DATE,
        TRIM(LS.SDLITM) AS PRODUCT_CODE,
        CASE
            /*
                SE FOR GRANEL E POSSUIR QTD NA TABELA DE INPUT DE PESAGEM,
                CONSIDERA QTD DESSA TABELA
            */
            WHEN TRIM(LS.SDSRP2) = '' AND T5.QSUORG::BIGINT > 0 THEN T5.QSUORG::BIGINT / 1000
            /*
                SE FOR DIFERENTE DE GRANEL OU SE FOR GRANEL E NAO POSSUIR QTD
                NA TABELA DE INPUT DE PESAGEM, BUSCAR QTD DO PESO PROGRAMADO
                NO LOAD
            */
            WHEN (
                TRIM(LS.SDSRP2) != ''
                OR (TRIM(LS.SDSRP2) = '' AND (T5.QSUORG::BIGINT = 0 OR T5.QSUORG::BIGINT IS NULL))
            )
                THEN F49.SUM_QXSOQS
            ELSE T5.QSUORG::BIGINT / 1000
        END AS TRANSPORTED_VOLUME,
        LS.SDUOM AS UM_PRODUCT,
        --(LS.SDCRCD) AS CURRENCY,
        'BRE' AS CURRENCY,
        CASE
            WHEN F901B.ACTUALSHIPDATE IS NOT NULL THEN F901B.ACTUALSHIPDATE
            WHEN LS.TMADDJ::BIGINT > 0 THEN
                (
                    DATEADD(
                        DAY,
                        SUBSTR((LS.TMADDJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                        TO_TIMESTAMP(
                            CONCAT(SUBSTR((LS.TMADDJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                            'YYYYMMDD'
                        )
                    )
                )
            ELSE NULL
        END AS LOAD_CONFIRMATION_DATE,
        CASE
            WHEN F901B.ACTUALSHIPDATE IS NOT NULL
                THEN F901B.ACTUALSHIPDATE
            WHEN T25.FDISSU::BIGINT != 0 AND T25.FDISSU IS NOT NULL
                THEN (
                    DATEADD(
                        DAY,
                        SUBSTR((T25.FDISSU::INT + 1900000)::STRING, 5, 3)::INT - 1,
                        TO_TIMESTAMP(
                            CONCAT(SUBSTR((T25.FDISSU::INT + 1900000)::STRING, 1, 4), '01', '01'),
                            'YYYYMMDD'
                        )
                    )
                )
            ELSE NULL
        END AS INVOICE_ISSUE_DATE,
        NULL AS OC_NUMBER,
        F76.SUM_FDUORG AS INVOICE_VOLUME,
        CASE
            WHEN T6.DRKY IS NOT NULL THEN T24.QSUORG::BIGINT / 1000
            ELSE F76.SUM_FDUORG
        END AS APPLIED_VOLUME,
        LS.SDDCTO AS TIPO_LOAD,
        (
            DATEADD(
                DAY,
                SUBSTR((T5.QSUPMJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                TO_TIMESTAMP(
                    CONCAT(SUBSTR((T5.QSUPMJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                    'YYYYMMDD'
                )
            )
        ) AS DATA_SAIDA_PESAGEM,
        CASE
            /* QDO LOAD EXISTIR NA F5549200, BUSCAR FRETE DESSA TABELA */
            WHEN TRIM(T17.CTMOT) != '' THEN TRIM(T17.CTMOT)
            /* QDO EXISTIR TN ASSOCIADA AO LOAD, BUSCAR FRETE DA TN */
            WHEN T7.RCLDNM > 0 AND TRIM(T7.RCDL011) != ''
                THEN
                    CASE
                        WHEN T23.VDAA10 = 'C' THEN 'CIF'
                        ELSE
                            CASE
                                WHEN T23.VDAA10 = 'F' THEN 'FOB'
                            END
                    END
            /*
                QDO NAO EXISTIR TN ASSOCIADA AO LOAD, BUSCAR O TIPO DE
                FRETE DO PEDIDO ASSOCIADO AO LOAD
            */
            ELSE
                CASE
                    WHEN TRIM(LS.SDFRTH) = 'FOB' THEN 'FOB'
                    ELSE 'CIF'
                END
        END AS TIPO_FRETE,
        CASE
            WHEN F801A.DATA_RECEPCAO_PORTO IS NOT NULL THEN F801A.DATA_RECEPCAO_PORTO
            WHEN T22.PDDGL > 0 AND T22.PDLTTR = '380' AND T22.PDNXTR = '400' THEN
                (
                    DATEADD(
                        DAY,
                        SUBSTR((T22.PDDGL::INT + 1900000)::STRING, 5, 3)::INT - 1,
                        TO_TIMESTAMP(
                            CONCAT(SUBSTR((T22.PDDGL::INT + 1900000)::STRING, 1, 4), '01', '01'),
                            'YYYYMMDD'
                        )
                    )
                )
            ELSE NULL
        END DT_RECEPCAO_JDE,
        LS.SDDOCO AS PEDIDO,
        LS.SDDCTO AS TIPO_PEDIDO,
        LS.SDSRP1 AS FINALIDADE_PEDIDO,
        LS.SDLNTY AS TIPO_DA_LINHA_PEDIDO,
        (
            DATEADD(
                DAY,
                SUBSTR((LS.SDTRDJ::INT + 1900000)::STRING, 5, 3)::INT - 1,
                TO_TIMESTAMP(
                    CONCAT(SUBSTR((LS.SDTRDJ::INT + 1900000)::STRING, 1, 4), '01', '01'),
                    'YYYYMMDD'
                )
            )
        ) AS DATA_PEDIDO,
        TRIM(T24.QSDESC) AS LOTID,
        T25.FDBNNF AS NF_NUM,
        T25.FDBSER AS NF_SERIE,
        DECODE(
            T25.FDNXTR, '605', '630', '607', '999', '617', '630', '620', '630',
            T25.FDNXTR
        ) AS NF_STATUS,
        T17.CTSHAN AS ADDRESS_COLETA,
        --LS.SDSHAN AS DESTINO_FINAL
        CASE
            WHEN LS.SDDCTO IN ('S8', 'T8') AND REPLACE(T22.PDLOTN, ' ', '') != ''
                AND T101.PDMCU IS NOT NULL
            -- LOAD DE TRANSBORDO COM LOTE PREENCHIDO E SEGUNDO LOAD C/ DESTINO FINAL CRIADO
                THEN TRIM(T101.PDMCU)
            WHEN LS.SDDCTO IN ('S8', 'T8') AND REPLACE(T22.PDLOTN, ' ', '') != '' AND F41.LOCATIONID IS NOT NULL
                AND T101.PDMCU IS NULL
            -- LOAD DE TRANBSBORDO COM LOTE PREENCHIDO MAS NAO TEM SEGUNDO LOAD C/ DESTINO FINAL OU LOAD REFERENTE AO DESTINO FINAL
                THEN TRIM(F41.LOCATIONID)
            WHEN LS.SDDCTO IN ('S8', 'T8') AND REPLACE(T22.PDLOTN, ' ', '') != ''
                AND T101.PDMCU IS NULL
            -- LOAD DE TRANBSBORDO COM LOTE PREENCHIDO MAS NAO TEM SEGUNDO LOAD C/ DESTINO FINAL OU LOAD REFERENTE AO DESTINO FINAL
                THEN TRIM(T22.PDMCU)
            WHEN LS.SDDCTO IN ('S8', 'T8')
                AND (REPLACE(T22.PDLOTN, ' ', '') = '' OR T22.PDLOTN IS NULL)
                AND LS.SDSHAN = T102.CIAN8
            -- LOAD DE TRANSBORDO SEM LOTE E COM ADDRESS DESTINO IGUAL A BP DESTINO
                THEN TRIM(T22.PDMCU)
            WHEN LS.SDDCTO IN ('S8', 'T8')
                AND (REPLACE(T22.PDLOTN, ' ', '') = '' OR T22.PDLOTN IS NULL)
                AND LS.SDSHAN != T102.CIAN8 AND F41.LOCATIONID IS NOT NULL
            -- LOAD DE TRANSBORDO SEM LOTE E COM ADDRESS DESTINO DO PEDIDO DIFERENTE DO ADDRESS DA BP DESTINO E QUE POSSUI BP TIPO PORTO ASSOCIADA NA F41001
                THEN TRIM(F41.LOCATIONID)
            WHEN LS.SDDCTO IN ('S8', 'T8')
                AND (REPLACE(T22.PDLOTN, ' ', '') = '' OR T22.PDLOTN IS NULL)
                AND LS.SDSHAN != T102.CIAN8 AND F41.LOCATIONID IS NULL
            -- LOAD DE TRANSBORDO SEM LOTE E COM ADDRESS DESTINO DO PEDIDO DIFERENTE DO ADDRESS DA BP DESTINO E QUE NAO POSSUI BP ASSOCIADA NA F41001
                THEN TRIM(T22.PDMCU)
            WHEN LS.SDDCTO IN ('SJ', 'S6') AND F41.LOCATIONID IS NOT NULL
                THEN TRIM(F41.LOCATIONID)
            ELSE TRIM(T22.PDMCU)
            -- DEMAIS OPERACOES DE TRANSFERENCIA
        END AS FINALDESTINATION,
        -- Adicionado por Vitor Souza
        -- Para validar regra de final destination na query tab_shipment_details_stg
        CASE
            WHEN
                (LS.SDDCTO IN ('S8', 'T8') AND REPLACE(T22.PDLOTN, ' ', '') != '' AND T101.PDMCU IS NOT NULL) --noqa
                THEN 'TRUE'
            ELSE
                'FALSE'
        END AS FINALDESTINATION_REAL,
        T26.PALLET,
        T26.PALLETQUANTITY,
        LS.SHURAT / 100 AS PLANNED_FREIGHT,
        CASE
            WHEN (T22.PDLTTR = '620' AND T22.PDNXTR = '620')
            OR (T22.PDLTTR = '560' AND T22.PDNXTR = '620')
                THEN 'TRUE'
            ELSE 'FALSE'
        END AS SINISTRO,
        TRIM(F12TE.SLB76AKEY) AS CHAVE_NF
    /* DADOS CABECALHO LOAD */
    FROM LOAD_STAGE AS LS
    /* DADOS PEDIDO DESTINO */
    LEFT JOIN CTE_F43199 AS T3
        ON
            LS.SDRKCO = T3.OLKCOO
            AND LS.SDRORN = T3.OLDOCO
            AND LS.SDRCTO = T3.OLDCTO
    /*DADOS PESAGEM ORIGEM*/
    LEFT JOIN {{ source('jde', 'F5549001') }} AS T5
        ON
            LS.QXKCOO = T5.QSKCOO
            AND LS.QXLDNM::STRING = T5.QSDOCO::STRING
            AND LS.QXDCTO = T5.QSDCTO
            AND LS.QXMCU = T5.QSMCU
            AND T5.QSZ55TOPE = '2'
            AND {{ filter_remove_jde_delete_data('T5') }}
    /* UDC OPERACOES TRANSFERENCIA */
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T6
        ON
            T6.DRSY = '55BR'
            AND T6.DRRT = 'A6'
            AND LPAD(LS.QXDCTO, 10, ' ') = T6.DRKY
            AND {{ filter_remove_jde_delete_data('T6') }}
    /* DADOS OC E TN */
    LEFT JOIN {{ source('jde', 'F5549701') }} AS T7
        ON
            LS.TMLDNM = T7.RCLDNM
            AND LS.TMVMCU = T7.RCVMCU
            AND TRY_CAST(T7.RCDOCO AS BIGINT) > 0
            AND {{ filter_remove_jde_delete_data('T7') }}
    /* DADOS TRANSPORTADORA */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T12
        ON
            LS.TMCARS = T12.ABAN8
            AND {{ filter_remove_jde_delete_data('T12') }}
    /* ASSOCIACAO PEDIDO X TN */
    LEFT JOIN {{ source('jde', 'F554201D') }} AS T16
        ON
            LS.QXKCOO = T16.OEKCOO
            AND LS.QXDOCO::STRING = T16.OEDOCO::STRING
            AND LS.QXDCTO = T16.OEDCTO
            AND T16.OESHAN > 0
            AND {{ filter_remove_jde_delete_data('T16') }}
    -- /* DADOS LOAD x CTMS */
    LEFT JOIN {{ source('jde', 'F5549200') }} AS T17
        ON
            LS.TMVMCU = T17.CTVMCU
            AND LS.TMLDNM = T17.CTLDNM
            AND {{ filter_remove_jde_delete_data('T17') }}
    -- /* DADOS TN */
    LEFT JOIN {{ source('jde', 'F5549400') }} AS T18
        ON
            T7.RCKCOO = T18.VHKCOO
            AND T7.RCDOCO::STRING = T18.VHDOCO::STRING
            AND T7.RCDCTO = T18.VHDCTO
            AND {{ filter_remove_jde_delete_data('T18') }}
    /* UDC TIPO DE OPERACAO BUSCA PELA TN */
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T19
        ON
            T19.DRSY = '55BR'
            AND T19.DRRT = 'M4'
            AND LPAD(RTRIM(T18.VHFRTH), 8, ' ') = RTRIM(T19.DRKY)
            AND {{ filter_remove_jde_delete_data('T19') }}
    /* UDC TIPO DE OPERACAO BUSCA PELO LOAD */
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T20
        ON
            LPAD(T17.CTEV02, 8, ' ') = RTRIM(T20.DRKY)
            AND T20.DRSY = '55BR'
            AND T20.DRRT = 'M4'
            AND {{ filter_remove_jde_delete_data('T20') }}
    /* DADOS RECEPCAO DESTINO */
    LEFT JOIN {{ source('jde', 'F4311') }} AS T22
        ON
            LS.TMLDNM = T22.PDURAB
            AND T22.PDDCTO not in ('TR', 'OR', 'OH')
            AND LPAD(LS.QXDOCO, 8, '0') = T22.PDRORN
            -- T22.PDLTTR = '380'
            --AND T22.PDNXTR = '400'
            AND {{ filter_remove_jde_delete_data('T22') }}
    /* DADOS TRANSP. CARGILL TRANSPORTES */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T11
        ON
            T17.CTANCR = T11.ABAN8
            AND {{ filter_remove_jde_delete_data('T11') }}
    LEFT JOIN CTE_F5549401 AS T23 ON T23.VDDL011 = T7.RCDL011
    LEFT JOIN CTE_F5549015 AS F49
        ON
            F49.QXLDNM = LS.QXLDNM
            AND F49.QXMCU = LS.QXMCU
            AND F49.QXLITM = LS.QXLITM
    LEFT JOIN {{ source('jde', 'F5549001') }} AS T24
            ON T24.QSDOCO::STRING = LS.TMLDNM::STRING
           AND T24.QSKCOO = T22.PDKCOO
           AND T24.QSDCTO = T22.PDDCTO
           AND {{ filter_remove_jde_delete_data('T24') }}
    LEFT JOIN {{ source('jde', 'F7611B') }} AS T25
            ON LS.SDKCOO = T25.FDKCOO
            AND LS.SDDOCO::STRING = T25.FDDOCO::STRING
            AND LS.SDDCTO = T25.FDPDCT
            AND LS.SDLNID = T25.FDLNID
            AND LS.QXLDNM = T25.FDN002
            AND {{ filter_remove_jde_delete_data('T25') }}
    LEFT JOIN CTE_F7611B AS F76
        ON
            F76.FDN002 = T25.FDN002
            AND F76.FDDCT = T25.FDDCT
            AND F76.FDITM = T25.FDITM
            AND F76.FDBNNF = T25.FDBNNF
            AND F76.FDBSER = T25.FDBSER
    LEFT JOIN {{ source('jde', 'F7601B') }} AS F01B
        ON
            T25.FDBNNF = F01B.FHBNNF
            AND T25.FDBSER = F01B.FHBSER
            AND T25.FDN001 = F01B.FHN001
            AND T25.FDDCT = F01B.FHDCT
            AND LS.TMLDNM = F01B.FHN002
            AND F01B.FHDCT = 'NS'
            AND {{ filter_remove_jde_delete_data('F01B') }}
    LEFT JOIN {{ source('jde', 'F76B12TE') }} AS F12TE
        ON
            F01B.FHBNNF = F12TE.SLBNNF
            AND F01B.FHBSER = F12TE.SLBSER
            AND F01B.FHDCT = F12TE.SLDCT
            AND F01B.FHN001 = F12TE.SLN001
            AND F12TE.SLB76NFST = 'A'
            AND NULLIF(TRIM(F12TE.SLB76AKEY), '') IS NOT NULL
            AND {{ filter_remove_jde_delete_data('F12TE') }}
    LEFT JOIN CTE_F554901B AS F901B ON LS.TMLDNM = F901B.LOAD_NUMBER
    LEFT JOIN CTE_F554801A AS F801A ON LS.TMLDNM = F801A.LOAD_NUMBER
    LEFT JOIN CTE_F4311 AS T101
        ON
            T22.PDLOTN = T101.PDLOTN
            AND T22.PDITM = T101.PDITM
            AND T22.PDKCOO = T101.PDKCOO
            AND T22.PDDGL <= IFF(
                T101.PDDGL < T101.PDADDJ, T101.PDADDJ, T101.PDDGL
            ) + 15
            -- AND T22.PDDGL BETWEEN T101.PDDGL - 15 AND T101.PDDGL + 15
            AND T22.PDURAB != T101.PDURAB
    LEFT JOIN {{ source('jde', 'F41001') }} AS T102
        ON T3.OLMCU = T102.CIMCU
    LEFT JOIN CTE_T102 AS F41
        ON LS.SDSHAN = F41.ADDRESS_NUMBER
    LEFT JOIN {{ ref('tab_shipment_pallet_stg') }} AS T26
        ON
            LS.TMLDNM = T26.LOAD_NUMBER
    WHERE
        1 = 1
)

SELECT
    -- Toda transferência de nota global é considerada FBZ - Vitor Souza
    CASE
        WHEN (
            LD.OPERATION_TYPE = 'TRF'
            AND NOTA_GLOBAL.LOADNUMBER IS NOT NULL
            AND NOTA_GLOBAL.OPERATION_TYPE != 'CIF'
        ) THEN 'FBZ'
        WHEN (
            LD.OPERATION_TYPE = 'FBZ'
            AND NOTA_GLOBAL.LOADNUMBER IS NULL
        ) THEN 'TRF'
        ELSE LD.OPERATION_TYPE
    END AS OPERATION_TYPE,
    LD.BRANCH_PLANT_SOURCE,
    LD.NEGOTIATION_BRANCH_PLANT,
    LD.ADDRESS_DESTINATION,
    LD.LOAD_NUMBER,
    LD.LOAD_STATUS_CODE,
    LD.LOAD_STATUS,
    IFF(LD.LOAD_STATUS_CODE = '98', 'N/A', NULL) AS ORIGINATION_CONTRACT,
    LD.MODAL,
    LD.CARRIER_ADDRESS,
    LD.CARRIER_NAME,
    LD.PLATE,
    LD.DRIVER_NAME,
    LD.SCHEDULED_SHIPPING_DATE,
    LD.SCHEDULED_LOAD_DATE,
    LD.PRODUCT_CODE,
    LD.TRANSPORTED_VOLUME,
    LD.UM_PRODUCT,
    LD.CURRENCY,
    LD.LOAD_CONFIRMATION_DATE,
    LD.INVOICE_ISSUE_DATE,
    LD.OC_NUMBER,
    ROUND(
        LD.INVOICE_VOLUME
        * COALESCE(IFF(NOTA_GLOBAL.RATEIO > 1, 1, NOTA_GLOBAL.RATEIO), 1),
        0
    ) AS INVOICE_VOLUME,
    ROUND(
        LD.APPLIED_VOLUME
        * COALESCE(IFF(NOTA_GLOBAL.RATEIO > 1, 1, NOTA_GLOBAL.RATEIO), 1),
        0
    ) AS APPLIED_VOLUME,
    LD.TIPO_LOAD,
    LD.DATA_SAIDA_PESAGEM,
    LD.TIPO_FRETE,
    LD.PEDIDO,
    LD.TIPO_PEDIDO,
    LD.FINALIDADE_PEDIDO,
    LD.TIPO_DA_LINHA_PEDIDO,
    LD.DATA_PEDIDO,
    LD.NF_NUM,
    LD.NF_SERIE,
    LD.NF_STATUS,
    LD.LOTID,
    IFF(ADDRESS_COLETA = 0, NULL, LD.ADDRESS_COLETA) AS ADDRESS_COLETA,
    LD.PALLET,
    LD.PALLETQUANTITY,
    CASE
        WHEN (INVOICE_VOLUME::BIGINT / 185) - TRUNC(INVOICE_VOLUME::BIGINT / 185) = 0 AND PALLET IS NOT NULL
            THEN '5 de Alta'
        WHEN (INVOICE_VOLUME::BIGINT / 148) - TRUNC(INVOICE_VOLUME::BIGINT / 148) = 0 AND PALLET IS NOT NULL
            THEN '4 de Alta'
        WHEN PALLET IS NOT NULL
            THEN 'Erro Palletização'
        ELSE NULL
    END AS PROFILE,
    LD.PLANNED_FREIGHT,
    LD.SINISTRO,
    MAX(
        CASE
            WHEN LD.OPERATION_TYPE = 'VEN' THEN NULL
            ELSE LD.BRANCH_PLANT_DESTINATION
        END
    ) AS BRANCH_PLANT_DESTINATION,
    MAX(LD.DT_RECEPCAO_JDE) AS DT_RECEPCAO_JDE,
    MAX(
        COALESCE(F42.LOCATIONID, BP.LOCATION_TO, LD.FINALDESTINATION)
    ) AS FINALDESTINATION,
    MAX(LD.FINALDESTINATION_REAL) AS FINALDESTINATION_REAL,
    MAX(LD.CHAVE_NF) AS CHAVE_NF
FROM LOAD_FINAL AS LD
LEFT JOIN BP
    ON LD.FINALDESTINATION  = BP.LOCATION_FROM
LEFT JOIN {{ ref('tab_location_internal_stg') }} AS F42
    ON LD.BRANCH_PLANT_DESTINATION = F42.LOCATIONID
    AND LOCATION_UNIT_STRUCTURE IN ('PORTO MARÍTIMO', 'FÁBRICA')
LEFT JOIN NOTA_GLOBAL
    ON NOTA_GLOBAL.LOADNUMBER = LD.LOAD_NUMBER
WHERE
    1 = 1
    AND NOT EXISTS (
        SELECT 1
        FROM {{ ref('tab_location_internal_stg') }} AS L
        WHERE
            1 = 1
            AND LD.BRANCH_PLANT_SOURCE = L.LOCATIONID
            AND L.LOCATION_TYPE = 'FORMAÇÃO DE LOTE'
            AND LD.MODAL = 'Rodoviário'
            AND LD.TIPO_PEDIDO = 'SJ'
    )
    -- Remoção de carragemntos da operação, ocorrido entre 12/2024 e 03/2025 china - 14/04/2025 - Vitor Souza
    AND NOT (
        LD.TIPO_PEDIDO = 'SJ'
        AND LD.LOAD_STATUS_CODE = '80'
        AND LD.BRANCH_PLANT_DESTINATION IN (
            '0217129015',
            '0217131558',
            '0217122223',
            '0217121919',
            '0217123601',
            '0217130103',
            '0217146927'
        )
    )
    AND NOT (
        LD.OPERATION_TYPE = 'TRF'
        AND LD.BRANCH_PLANT_SOURCE IN (
            SELECT SOURCE_CODE
            FROM UDC
            WHERE
                1 = 1
                AND CATEGORY = 'SHIPMENT'
                AND STAGE = 'EXCLUI_BP_ORIGEM'
        )
    )
GROUP BY
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
    39, 40, 41, 42
