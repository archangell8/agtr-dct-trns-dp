-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}

WITH
LOAD_STATUS_30_98 AS (
    SELECT DISTINCT
        CASE
            WHEN T18.VHFRTH IS NOT NULL THEN TRIM(T19.DRSPHD)
            WHEN T17.CTEV02 IS NOT NULL THEN TRIM(T20.DRSPHD)
            WHEN T6.DRKY IS NOT NULL THEN 'TRF'
            ELSE 'VEN'
        END AS OPERATION_TYPE,
        TRIM(T0.TMVMCU) AS BRANCH_PLANT_SOURCE,
        CASE
            WHEN T18.VHMCU IS NOT NULL THEN TRIM(T18.VHMCU)
            ELSE TRIM(T3.SHMCU)
        END AS NEGOTIATION_BRANCH_PLANT,
        TRUNC(
            TO_CHAR(
            CASE
                WHEN (T16.OESHAN IS NOT NULL) THEN T16.OESHAN
                ELSE T2.SDSHAN
            END
            )
        )::STRING AS ADDRESS_DESTINATION,
        TRIM(T4.OLMCU) AS BRANCH_PLANT_DESTINATION,
        T0.TMLDNM AS LOAD_NUMBER,
        T0.TMLDLS AS LOAD_STATUS_CODE,
        CASE
            WHEN T0.TMLDLS = '30' THEN 'Load Aprovado'
            WHEN T0.TMLDLS = '98' THEN 'Load Cancelado'
            WHEN T0.TMLDLS = '20' THEN 'Load Nao Aprovado'
        END AS LOAD_STATUS,
        TRIM(T18.VHDMCT) AS ORIGINATION_CONTRACT,
        TRIM(T14.DRDL01) AS MODAL,
        CASE
            WHEN T17.CTCPFG = 'S' THEN TO_CHAR(T17.CTANCR)
            ELSE TO_CHAR(T0.TMCARS)
        END AS CARRIER_ADDRESS,
        CASE
            WHEN T17.CTCPFG = 'S' THEN TRIM(T11.ABALPH)
            ELSE TRIM(T12.ABALPH)
        END AS CARRIER_NAME,
        TRIM(T0.TMPVEH) AS PLATE,
        CASE
            WHEN (
                TRIM(T17.CTALPH) IS NOT NULL
                AND TRIM(T17.CTALPH) != ' '
            )
                THEN TRIM(T17.CTALPH)
            ELSE TRIM(T15.CMALPH)
        END AS DRIVER_NAME,
        CASE
            WHEN T0.TMLOAD > 0 THEN  {{ julian_date_to_gregorian('T0', 'TMLOAD') }}
            ELSE NULL
        END AS SCHEDULED_LOAD_DATE,
        CASE
            WHEN T2.SDDRQJ::BIGINT > 0 THEN {{ julian_date_to_gregorian('T2', 'SDDRQJ') }}
            ELSE NULL
        END AS SCHEDULED_SHIPPING_DATE,
        TRIM(T2.SDLITM) AS PRODUCT_CODE,
        CASE
            /*
                SE FOR GRANEL E POSSUIR QTD NA TABELA DE INPUT DE PESAGEM,
                CONSIDERA QTD DESSA TABELA
            */
            WHEN T2.SDSRP2 = ' ' AND T5.QSUORG > 0 THEN T5.QSUORG::BIGINT / 1000
            /*
                SE FOR DIFERENTE DE GRANEL OU SE FOR GRANEL E NAO POSSUIR QTD
                NA TABELA DE INPUT DE PESAGEM, BUSCAR QTD DO PESO PROGRAMADO
                NO LOAD
            */
            WHEN (
                T2.SDSRP2 != ' '
                OR (T2.SDSRP2 = ' ' AND (T5.QSUORG = 0 OR T5.QSUORG IS NULL))
            )
                THEN (
                    SELECT SUM(F49621.TDSCLQ::BIGINT / 1000)
                    FROM {{ source('jde', 'F49621') }} AS F49621
                    WHERE
                        1 = 1
                        AND F49621.TDLDNM = T1.TDLDNM
                        AND F49621.TDVMCU = T1.TDVMCU
                        AND F49621.TDITM = T1.TDITM
                        AND {{ filter_remove_jde_delete_data('F49621') }}
                )
            ELSE T5.QSUORG::BIGINT / 1000
        END AS TRANSPORTED_VOLUME,
        T2.SDUOM AS UM_PRODUCT,
        --TRIM(T2.SDCRCD) AS CURRENCY,
        'BRE' AS CURRENCY,
        --T7.RCUKID AS OC_NUMBER,
        NULL AS OC_NUMBER,
        T2.SDDOCO AS PEDIDO,
        T2.SDDCTO AS TIPO_PEDIDO,
        --T2.SDLNID AS LINHA_PEDIDO,
        T2.SDSRP1 AS FINALIDADE_PEDIDO,
        T2.SDLNTY AS TIPO_DA_LINHA_PEDIDO,
        {{ julian_date_to_gregorian('T2', 'SDTRDJ') }} AS DATA_PEDIDO,
        TRIM(T5.QSDESC) AS LOTID,
        T21.PALLET AS PALLET,
        T21.PALLETQUANTITY,
        T3.SHURAT / 100 AS PLANNED_FREIGHT
    /* DADOS CABEÇALHO LOAD */
    FROM {{ source('jde', 'F4960') }} AS T0
    /* DADOS PEDIDOS ASSOCIADOS AO LOAD */
    INNER JOIN {{ source('jde', 'F49621') }} AS T1
        ON
            T0.TMVMCU = T1.TDVMCU
            AND T0.TMLDNM = T1.TDLDNM
            AND {{ filter_remove_jde_delete_data('T1') }}
    /* DADOS PEDIDO ORIGEM */
    INNER JOIN {{ source('jde', 'F4211') }} AS T2
        ON
            T1.TDKCOO = T2.SDKCOO
            AND T1.TDDOCO = T2.SDDOCO
            AND T1.TDDCTO = T2.SDDCTO
            AND T1.TDLNID = T2.SDLNID
            AND {{ filter_remove_jde_delete_data('T2') }}
    /* DADOS CABEÇALHO PEDIDO / BP NEGOCIACAO */
    INNER JOIN {{ source('jde', 'F4201') }} AS T3
        ON
            T1.TDKCOO = T3.SHKCOO
            AND T1.TDDOCO = T3.SHDOCO
            AND T1.TDDCTO = T3.SHDCTO
            AND {{ filter_remove_jde_delete_data('T3') }}
    /* DADOS PEDIDO DESTINO */
    LEFT JOIN {{ source('jde', 'F43199') }} AS T4
        ON
            T2.SDRKCO = T4.OLKCOO
            AND TRY_CAST(TRIM(T2.SDRORN) AS BIGINT) = TRY_CAST(T4.OLDOCO AS BIGINT)
            AND T2.SDRCTO = T4.OLDCTO
            AND T4.OLLNID = 1000
            --AND T4.OLDOCO > 0
            --AND TRIM(T4.OLDCTO) != ''
            --AND TRIM(T4.OLKCOO) != ''
            AND {{ filter_remove_jde_delete_data('T4') }}
    /* DADOS PESAGEM ORIGEM */
    LEFT JOIN {{ source('jde', 'F5549001') }} AS T5
        ON
            T1.TDKCOO = T5.QSKCOO
            AND T1.TDLDNM = T5.QSDOCO
            AND T1.TDDCTO = T5.QSDCTO
            AND T1.TDVMCU = T5.QSMCU
            AND T5.QSZ55TOPE = '2' -- 2 = SAÿDA
            AND {{ filter_remove_jde_delete_data('T5') }}
    /* UDC OPERACOES TRANSFERENCIA */
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T6
        ON
            T6.DRSY = '55BR'
            AND T6.DRRT = 'A6'
            AND LPAD(T1.TDDCTO, 10, ' ') = T6.DRKY
            AND {{ filter_remove_jde_delete_data('T6') }}
    /* DADOS OC E TN */
    LEFT JOIN {{ source('jde', 'F5549701') }} AS T7
        ON
            T0.TMLDNM = T7.RCLDNM
            AND T0.TMVMCU = T7.RCVMCU
            AND T7.RCDOCO > 0
            AND TRIM(T7.RCKCOO) != ''
            AND {{ filter_remove_jde_delete_data('T7') }}
    /* DADOS LOAD x CTMS */
    LEFT JOIN {{ source('jde', 'F5549200') }} AS T17
        ON
            T0.TMVMCU = T17.CTVMCU
            AND T0.TMLDNM = T17.CTLDNM
            AND {{ filter_remove_jde_delete_data('T17') }}
    /* DADOS TRANSP. CARGILL TRANSPORTES */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T11
        ON
            T17.CTANCR = T11.ABAN8
            AND {{ filter_remove_jde_delete_data('T11') }}
    /* DADOS TRANSPORTADORA */
    LEFT JOIN {{ source('jde', 'F0101') }} AS T12
        ON
            T0.TMCARS = T12.ABAN8
            AND {{ filter_remove_jde_delete_data('T12') }}
    /* DADOS VEÿCULO */
    -- VERIFICAR APÓS NORMALIZAÇÃO AMBIENTE 28/03/2025
    LEFT JOIN {{ source('jde', 'F4930') }} AS T13
        ON
            T0.TMPVEH = T13.VMVEHI
            AND {{ filter_remove_jde_delete_data('T13') }}
    /* UDC MODAL */
    LEFT JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T14
        ON
            T14.DRSY = '55BR'
            AND T14.DRRT = 'DM'
            AND LPAD(T13.VMURCD, 10, ' ') = T14.DRKY
            AND {{ filter_remove_jde_delete_data('T14') }}
    /* DADOS MOTORISTA */
    INNER JOIN {{ source('jde', 'F5549100') }} AS T15
        ON T0.TMRLNO = T15.CMRLNO
        AND {{ filter_remove_jde_delete_data('T15') }}
    /* ASSOCIACAO PEDIDO X TN */
    LEFT JOIN {{ source('jde', 'F554201D') }} AS T16
        ON
            T1.TDKCOO = T16.OEKCOO
            AND T1.TDDOCO = T16.OEDOCO
            AND T1.TDDCTO = T16.OEDCTO
            AND T16.OESHAN > 0
            AND {{ filter_remove_jde_delete_data('T16') }}
    /* DADOS TN */
    LEFT JOIN {{ source('jde', 'F5549400') }} AS T18
        ON
            T7.RCKCOO = T18.VHKCOO
            AND T7.RCDOCO = T18.VHDOCO
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
            T20.DRSY = '55BR'
            AND T20.DRRT = 'M4'
            AND LPAD(T17.CTEV02, 8, ' ') = RTRIM(T20.DRKY)
            AND {{ filter_remove_jde_delete_data('T20') }}
    LEFT JOIN {{ ref('tab_shipment_pallet_stg') }} AS T21
        ON
            T0.TMLDNM = T21.LOAD_NUMBER
    WHERE
        1 = 1
        AND T0.TMVMCU IN (
            SELECT MCMCU
            FROM {{ source('jde', 'F0006') }}
            WHERE
                1 = 1
                AND MCCO IN ('52171','52191', '52180')
                AND MCSTYL = 'BP'
                AND LENGTH(TRIM(MCMCU)) = 10
                AND {{ filter_remove_jde_delete_data('F0006') }}
        )
        AND T0.TMLDNM > 0
        AND T0.TMLOAD >= 125000
        AND T0.TMLDLS IN ('30','20') -- STATUS DO LOAD
        AND {{ filter_remove_jde_delete_data('T0') }}
        AND T2.SDDCTO != 'SD'
)

SELECT
    OPERATION_TYPE,
    BRANCH_PLANT_SOURCE,
    NEGOTIATION_BRANCH_PLANT,
    ADDRESS_DESTINATION,
    CASE
        WHEN OPERATION_TYPE = 'VEN' THEN NULL
        ELSE BRANCH_PLANT_DESTINATION
    END AS BRANCH_PLANT_DESTINATION,
    LOAD_NUMBER,
    LOAD_STATUS_CODE,
    LOAD_STATUS,
    ORIGINATION_CONTRACT,
    MODAL,
    CARRIER_ADDRESS,
    CARRIER_NAME,
    PLATE,
    DRIVER_NAME,
    SCHEDULED_LOAD_DATE,
    SCHEDULED_SHIPPING_DATE,
    PRODUCT_CODE,
    TRANSPORTED_VOLUME,
    UM_PRODUCT,
    CURRENCY,
    OC_NUMBER,
    PEDIDO,
    TIPO_PEDIDO,
    --LINHA_PEDIDO,
    FINALIDADE_PEDIDO,
    TIPO_DA_LINHA_PEDIDO,
    DATA_PEDIDO,
    LOTID,
    PALLET,
    --SUM(PALLETQUANTITY) AS PALLETQUANTITY,
    PALLETQUANTITY,
    -- CASE
    --     WHEN PALLET IS NOT NULL AND IFF(TRANSPORTED_VOLUME::BIGINT = 0, NULL, TRANSPORTED_VOLUME::BIGINT) / 24 = 185 THEN '5 de Alta'
    --     WHEN PALLET IS NOT NULL AND IFF(TRANSPORTED_VOLUME::BIGINT = 0, NULL, TRANSPORTED_VOLUME::BIGINT) / 24 = 148 THEN '4 de Alta'
    --     WHEN PALLET IS NOT NULL THEN 'Erro Palletizacao'
    -- END AS PROFILE,
    -- CASE
    --     WHEN (TRANSPORTED_VOLUME::BIGINT / 185) - TRUNC(TRANSPORTED_VOLUME::BIGINT / 185) = 0
    --         THEN '5 de Alta'
    --     WHEN (TRANSPORTED_VOLUME::BIGINT / 148) - TRUNC(TRANSPORTED_VOLUME::BIGINT / 148) = 0
    --         THEN '4 de Alta'
    --     WHEN PALLET IS NOT NULL
    --         THEN 'Erro Palletização'
    --     ELSE 'Erro Palletização'
    -- END AS PROFILE,
    CASE
        WHEN (TRANSPORTED_VOLUME::BIGINT / 185) - TRUNC(TRANSPORTED_VOLUME::BIGINT / 185) = 0 AND PALLET IS NOT NULL
            THEN '5 de Alta'
        WHEN (TRANSPORTED_VOLUME::BIGINT / 148) - TRUNC(TRANSPORTED_VOLUME::BIGINT / 148) = 0 AND PALLET IS NOT NULL
            THEN '4 de Alta'
        WHEN PALLET IS NOT NULL
            THEN 'Erro Palletização'
        ELSE NULL
    END AS PROFILE,
    PLANNED_FREIGHT
FROM LOAD_STATUS_30_98
GROUP BY
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
    31
