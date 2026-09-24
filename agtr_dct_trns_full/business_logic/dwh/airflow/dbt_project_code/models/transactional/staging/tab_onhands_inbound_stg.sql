-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}

WITH
TAB_ONHANDS_INBOUND AS (
    /* Caso seja a primeira execução, a tabela do modelo ainda não existe */
    {% set exists_table = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.table) %}
    {% if not exists_table %}
        SELECT
            'N/A' AS ITEM,
            'N/A' AS BP,
            'N/A' AS "LOCATION",
            'N/A' AS UOM,
            'N/A' AS "DAY",
            NULL AS COMPANY,
            NULL AS BLOCKEDQUANTITY,
            NULL AS ONHANDQUANTITY,
            NULL AS QUARANTINEQUANTITY

    /* Caso a tabela exista, referencia ela mesma */
    {% else %}
        SELECT DISTINCT *
        FROM {{ this }}

    {% endif %}
),


/* ONHANDS INBOUND SALDO CARDEX */
DATAS AS (
    SELECT
        {{ gregorian_date_to_julian('T', 'DIAANT') }} AS DIAANT, -- noqa
        {{ gregorian_date_to_julian('T', 'ANOANT') }} AS ANOANT, -- noqa
        {{ gregorian_date_to_julian('T', 'MESANT') }} AS MESANT, -- noqa
    FROM (
        SELECT
            CURRENT_DATE() AS DIAANT,
            LAST_DAY(
                ADD_MONTHS(
                    CURRENT_DATE(),
                    -TO_CHAR(
                        LAST_DAY(DATE_TRUNC('MONTH', CURRENT_DATE())), 'MM'
                    )
                )
            ) AS ANOANT,
            LAST_DAY(ADD_MONTHS(CURRENT_DATE(), -1)) AS MESANT
    ) AS T
),

SALDOINI AS (
    SELECT
        F4101.IMLITM AS PRODUTO,
        0 AS RESIDUO,
        0 AS SAIDA,
        0 AS ENTRADA,
        0 AS AJUSTE,
        0 AS OH_NAO_APLICADAS,
        0 AS OUTROS_NAO_MAPEADOS,
        'TN' AS UOM,
        REPLACE(LEFT(TRIM(F5560509.SRMCU), 5), '02', '52') AS COMPANHIA,
        TRIM(F5560509.SRMCU) AS BP,
        TO_CHAR(CURRENT_DATE(), 'DD/MM/YYYY') AS CURRENT_DATE1,
        SUM(F5560509.SRNQ03::DECIMAL(20, 3) / 1000 / 1000) AS SALDOINICIAL
    FROM {{ source('jde', 'F5560509') }} AS F5560509 --REMOVER -- noqa
    INNER JOIN {{ source('jde', 'F4101') }} AS F4101
        ON F4101.IMITM = F5560509.SRITM
    INNER JOIN DATAS ON F5560509.SRDGL = DATAS.ANOANT
    INNER JOIN {{ ref('item_master') }} AS IT
        ON IT.ITEM = F4101.IMLITM
    WHERE
        1 = 1
        AND F5560509.SRLNTY = '99'
        AND (
            F5560509.SRMCU LIKE '  02171%'
            OR F5560509.SRMCU LIKE '  02180%'
            OR F5560509.SRMCU LIKE '  02191%'
        )
        AND IT.ITEMSTAGE = 'GRAOS'
        AND {{ filter_remove_jde_delete_data('F5560509') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F4101') }} -- noqa
    GROUP BY
        F5560509.SRMCU,
        F5560509.SRITM,
        F4101.IMLITM,
        F4101.IMUOM1
    HAVING SUM(F5560509.SRNQ03::DECIMAL(20, 3) / 1000) != 0
),

CARDEX AS (
    SELECT
        F4111.ILLITM AS PRODUTO,
        F4101.IMDSC1 AS DESCRICAO,
        TRIM(F4111.ILMCU) AS BP,
        (
            F4111.ILTRQT::DECIMAL(20, 3)
            / 1000
            / UOM.SUPPLYPLANNINGFINALCONVERSIONFACTOR
        ) AS QUANTIDADE,
        F4111.ILDOC AS DOCUMENTO,
        F4111.ILDCTO AS TIPO_LINHA,
        F4111.ILDCT AS SUBTIPO_LINHA,
        F4111.ILDCT || '-' || F4111.ILDCTO AS DOC_TIPO,
        F4111.ILDOCO AS PEDIDO,
        F4111.ILLNID AS LINHA,
        F0006.MCCO AS COMPANHIA,
        CASE
            WHEN (SUBSTR(F4111.ILDGL, -3, 3) > 0) AND (SUBSTR(F4111.ILDGL, -3, 3) < 367) -- noqa
                THEN {{ julian_date_to_gregorian('F4111', 'ILDGL') }} -- noqa
            ELSE 'N/A' -- noqa
        END AS DATA_CONTABIL,
        TRIM(F4111.ILMCU) || '-' || F4111.ILLITM AS CHAVE,
        UOM.UOMFROM AS UOM,
        F4101.IMITM,
        DATAS.ANOANT,
        DATAS.MESANT
    FROM {{ source('jde', 'F4111') }} AS F4111 --REMOVER -- noqa
    INNER JOIN {{ source('jde', 'F4101') }} AS F4101
        ON F4111.ILLITM = F4101.IMLITM
    INNER JOIN {{ source('jde', 'F0006') }} AS F0006
        ON F4111.ILMCU = F0006.MCMCU
    INNER JOIN DATAS
        ON F4111.ILDGL > DATAS.ANOANT
    INNER JOIN {{ ref('item_master') }} AS IT
        ON IT.ITEM = F4101.IMLITM
    LEFT JOIN {{ ref('uom_conversion_master') }} AS UOM
        ON
            F4101.IMLITM = UOM.ITEM
            AND UOM.UOMTO = F4111.ILTRUM
    WHERE
        1 = 1
        AND IT.ITEMSTAGE = 'GRAOS'
        AND F4111.ILTRQT::DECIMAL(20, 3) != 0
        AND F0006.MCCO IN ('52171', '52180', '52191')
        -- Alterado por guilherme
        -- Motivo: registro na tabela F4111 com uom KM para milho
        -- Motivo: registro na tabela F4111 com uom KH para soja
        AND F4111.ILTRUM NOT IN ('KM', 'KH')
        AND {{ filter_remove_jde_delete_data('F4111') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F4101') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F0006') }} -- noqa
),

CARDEX_TEMP AS (
    SELECT
        F5560509.SRMCU,
        F5560509.SRDGL,
        F5560509.SRITM,
        SUM(F5560509.SRNQ03::BIGINT / 1000 / 1000) AS SUM_SRNQ03
    FROM {{ source('jde', 'F5560509') }} AS F5560509
    WHERE
        1 = 1
        AND F5560509.SRLNTY = '99'
        AND {{ filter_remove_jde_delete_data('F5560509') }} -- noqa
    GROUP BY
        F5560509.SRMCU,
        F5560509.SRDGL,
        F5560509.SRITM
),

CARDEX1 AS (
    SELECT
        CARDEX.PRODUTO,
        CARDEX.BP,
        CARDEX.UOM,
        CARDEX.COMPANHIA,
        TO_CHAR(CURRENT_DATE, 'DD/MM/YYYY') AS CURRENT_DATE1,
        MAX(CARDEX_TEMP.SUM_SRNQ03) AS SALDOINICIAL,
        SUM(
            CASE
                WHEN CARDEX.DOC_TIPO IN (
                    'LX-LX', 'LY-LY', 'I0-LX', 'LY-', 'I0-LY', 'LX-', 'LZ-LZ',
                    'RI-LX', 'I0-LZ', 'LZ-LZ', 'I0-LZ', 'LZ-', 'RI-LZ'
                ) THEN CARDEX.QUANTIDADE
                ELSE 0
            END
        ) AS RESIDUO,
        SUM(
            CASE
                WHEN CARDEX.DOC_TIPO IN (
                    'RI-SX', 'RI-DV', 'RI-SA', 'I6-T8', 'SX-SX', 'SD-SD',
                    'SA-SA', 'DV-', 'I0-DV', 'D7-', 'RI-S6', 'I0-S6', 'T8-T8',
                    'SI-SI', 'S7-S7', 'I0-S8', 'I0-VQ', 'I6-S6', 'I6-S7',
                    'I0-SJ', 'I6-SJ', 'I0-SD', 'RI-SJ', 'S8-S8', 'I0-SI',
                    'DV-DV', 'S6-S6', 'I6-SD', 'VQ-', 'VQ-VQ', 'RI-S8', 'I6-S8',
                    'SJ-SJ', 'I6-SI', 'I0-S7', 'RI-D7', 'I0-D7', 'D7-D7',
                    'RI-T8', 'I0-T8', 'RI-SI', 'I0-SX', 'RI-VQ', 'SX-', 'I0-SA',
                    'RI-S7', 'IM-', 'RI-S6', 'I0-S6', 'I0-A#', 'F5-F5', 'I0-F5',
                    'RI-F5', 'M1-', 'I0-SR', 'I0-V8', 'I0-VG', 'I6-SA', 'I6-SR',
                    'I6-VQ', 'RI-SR', 'RI-V8', 'RI-VG', 'SR-SR', 'V8-V8',
                    'VG-VG', 'SI-SI', 'S7-S7', 'I0-S8', 'I0-VQ', 'I6-S6',
                    'I6-S7', 'I0-SJ', 'I6-SJ', 'I0-SD', 'RI-SJ', 'S8-S8',
                    'I0-SI', 'DV-DV', 'S6-S6', 'I6-SD', 'VQ-', 'VQ-VQ', 'RI-S8',
                    'I6-S8', 'SJ-SJ', 'I6-SI', 'I0-S7', 'RI-D7', 'I0-D7',
                    'D7-D7', 'RI-T8', 'I0-T8', 'RI-SI', 'I0-SX', 'RI-VQ', 'SX-',
                    'I0-SA', 'RI-S7', 'IM-', 'RI-S6', 'I0-S6', 'I0-A#', 'F5-F5',
                    'I0-F5', 'RI-F5', 'M1-', 'I0-SR', 'I0-V8', 'I0-VG', 'I6-SA',
                    'I6-SR', 'I6-VQ', 'RI-SR', 'RI-V8', 'RI-VG', 'SR-SR',
                    'V8-V8', 'VG-VG'
                ) THEN CARDEX.QUANTIDADE
                ELSE 0
            END
        ) AS SAIDA,
        SUM(
            CASE
                WHEN CARDEX.DOC_TIPO IN (
                    'OD-OD', 'OV-OH', 'O8-O8', 'ED-', 'OJ-OJ', 'OV-O8', 'OV-OW',
                    'OV-O7', 'OH-', 'OV-OD', 'IC-', 'OV-OJ', 'O7-O7', 'F9-OH',
                    'F9-', 'OV-E5', 'OV-OI'
                ) THEN CARDEX.QUANTIDADE
                ELSE 0
            END
        ) AS ENTRADA,
        SUM(
            CASE
                WHEN CARDEX.DOC_TIPO IN (
                    'IS-',
                    'B0-',
                    'RI-A#',
                    'IA-',
                    'I3-'
                ) THEN CARDEX.QUANTIDADE
                ELSE 0
            END
        ) AS AJUSTE,
        SUM(0) AS OH_NAO_APLICADAS,
        SUM(
            CASE
                WHEN CARDEX.DOC_TIPO NOT IN (
                    'LX-LX', 'LY-LY', 'I0-LX', 'LY-', 'I0-LY', 'LX-', 'LZ-LZ',
                    'RI-LX', 'I0-LZ', 'LZ-LZ', 'I0-LZ', 'LZ-', 'RI-LZ', 'RI-SX',
                    'RI-DV', 'RI-SA', 'I6-T8', 'SX-SX', 'SD-SD', 'SA-SA', 'DV-',
                    'I0-DV', 'D7-', 'RI-S6', 'I0-S6', 'T8-T8', 'SI-SI', 'S7-S7',
                    'I0-S8', 'I0-VQ', 'I6-S6', 'I6-S7', 'I0-SJ', 'I6-SJ',
                    'I0-SD', 'RI-SJ', 'S8-S8', 'I0-SI', 'DV-DV', 'S6-S6',
                    'I6-SD', 'VQ-', 'VQ-VQ', 'RI-S8', 'I6-S8', 'SJ-SJ', 'I6-SI',
                    'I0-S7', 'RI-D7', 'I0-D7', 'D7-D7', 'RI-T8', 'I0-T8',
                    'RI-SI', 'I0-SX', 'RI-VQ', 'SX-', 'I0-SA', 'RI-S7', 'IM-',
                    'RI-S6', 'I0-S6', 'I0-A#', 'F5-F5', 'I0-F5', 'RI-F5', 'M1-',
                    'I0-SR', 'I0-V8', 'I0-VG', 'I6-SA', 'I6-SR', 'I6-VQ', 'I3-',
                    'RI-SR', 'RI-V8', 'RI-VG', 'SR-SR', 'V8-V8', 'VG-VG', 'IA-',
                    'SI-SI', 'S7-S7', 'I0-S8', 'I0-VQ', 'I6-S6', 'I6-S7',
                    'I0-SJ', 'I6-SJ', 'I0-SD', 'RI-SJ', 'S8-S8', 'I0-SI',
                    'DV-DV', 'S6-S6', 'I6-SD', 'VQ-', 'VQ-VQ', 'RI-S8', 'RI-A#',
                    'I6-S8', 'SJ-SJ', 'I6-SI', 'I0-S7', 'RI-D7', 'I0-D7',
                    'D7-D7', 'RI-T8', 'I0-T8', 'RI-SI', 'I0-SX', 'RI-VQ', 'SX-',
                    'I0-SA', 'RI-S7', 'IM-', 'RI-S6', 'I0-S6', 'I0-A#', 'F5-F5',
                    'I0-F5', 'RI-F5', 'M1-', 'I0-SR', 'I0-V8', 'I0-VG', 'I6-SA',
                    'I6-SR', 'I6-VQ', 'RI-SR', 'RI-V8', 'RI-VG', 'SR-SR',
                    'V8-V8', 'VG-VG', 'OD-OD', 'OV-OH', 'O8-O8', 'ED-', 'OJ-OJ',
                    'OV-O8', 'OV-OW', 'OV-O7', 'OH-', 'OV-OD', 'IC-', 'OV-OJ',
                    'O7-O7', 'F9-OH', 'F9-', 'OV-E5', 'OV-OI', 'IS-', 'B0-'
                ) THEN CARDEX.QUANTIDADE
                ELSE 0
            END
        ) AS OUTROS_NAO_MAPEADOS
    FROM CARDEX
    LEFT JOIN CARDEX_TEMP
        ON
            LPAD(CARDEX.BP, 12, ' ') = CARDEX_TEMP.SRMCU
            AND CARDEX.ANOANT = CARDEX_TEMP.SRDGL
            AND CARDEX.IMITM = CARDEX_TEMP.SRITM
    GROUP BY
        CARDEX.PRODUTO,
        CARDEX.BP,
        TO_CHAR(CURRENT_DATE, 'DD/MM/YYYY'),
        CARDEX.UOM,
        CARDEX.COMPANHIA
),

ONHANDS_SALDO_CADEX AS (
    SELECT
        TRIM(PRODUTO) AS PRODUTO,
        TRIM(BP) AS BP,
        UOM,
        CURRENT_DATE1,
        COMPANHIA,
        SALDOINICIAL,
        RESIDUO,
        SAIDA,
        ENTRADA,
        AJUSTE,
        OH_NAO_APLICADAS,
        OUTROS_NAO_MAPEADOS
    FROM CARDEX1

    UNION

    SELECT
        TRIM(PRODUTO) AS PRODUTO,
        TRIM(BP) AS BP,
        UOM,
        CURRENT_DATE1,
        COMPANHIA,
        SALDOINICIAL,
        RESIDUO,
        SAIDA,
        ENTRADA,
        AJUSTE,
        OH_NAO_APLICADAS,
        OUTROS_NAO_MAPEADOS
    FROM SALDOINI AS SLD
    WHERE NOT EXISTS (
        SELECT 1
        FROM CARDEX1
        WHERE
            1 = 1
            AND SLD.BP = CARDEX1.BP
            AND SLD.PRODUTO = CARDEX1.PRODUTO
    )
),


/* ONHANDS INBOUND OH NOT APPLIED */
SKU_ITEM AS (
    SELECT ITEM
    FROM {{ ref('item_master') }}
    WHERE L1 IN (
        'SOJA', 'MILHO', 'TRIGO', 'FARELO HI-PRO', 'FARELO DDG',
        'FARELO LO-PRO', 'OLEO DEGOMADO'
    )
),

CARDEX_CTE AS (
    SELECT DISTINCT
        CARDEX.ILDOCO,
        CARDEX.ILLNID,
        CARDEX.ILMCU,
        CARDEX.ILDCTO,
        SUM(CARDEX.ILTRQT / 1000) OVER (
            PARTITION BY CARDEX.ILMCU, CARDEX.ILLNID, CARDEX.ILDCTO
        ) AS VOL_CARDEX
    FROM {{ source('jde', 'F4111') }} AS CARDEX
    WHERE
        1 = 1
        AND CARDEX.ILLITM IN (
            --'00001', '00100', '00002', '00027', '00034', '00026', '90584',
            --'09127', '09311', '09369', '179891', '10068'
			SELECT ITEM FROM SKU_ITEM
        )
        AND CARDEX.ILKCO IN ('52171', '52180', '52191')
        AND CARDEX.ILDCTO IN ('', NULL, 'OV', ' ', 'OH')
        AND CARDEX.ILDCT IN ('', NULL, 'OV', ' ', 'OH')
        AND (
            {{ julian_date_to_gregorian('CARDEX', 'ILTRDJ') }} >
            ADD_MONTHS(CURRENT_DATE(), -3)
        )
        AND CARDEX.ILTRQT > 0
        AND {{ filter_remove_jde_delete_data('CARDEX') }}
),

CARGAS_PARADAS AS (
    SELECT
        F4311.PDMCU AS DESTINO,
        F4311.PDANBY AS ORIGEM,
        F4311.PDAN8 AS FAZENDA,
        F4311.PDDMCT AS CONTRATO,
        F4311.PDFRTH AS FRETE,
        F4311.PDLITM AS ITEM,
        F4311.PDDSC1 AS PRODUTO,
        F4311.PDDOCO AS NR_PEDIDO,
        F4311.PDDCTO AS DOC,
        F4311.PDLNID AS LINHA,
        F4311.PDOORN AS NR_NF,
        F4311.PDLTTR || '-' || F4311.PDNXTR AS STATUS,
        {{ julian_date_to_gregorian('F4311', 'PDPDDJ') }} AS DATA_TRANSACAO,
        {{ julian_date_to_gregorian('F4311', 'PDDGL') }} AS DATA_CONTABIL,
        F4311.PDUORG / 1000
        / SUPPLYPLANNINGFINALCONVERSIONFACTOR AS VOLUME_NF,
        F4311.PDUREC / 1000
        / SUPPLYPLANNINGFINALCONVERSIONFACTOR AS VOL_APLICADO,
        F4311.PDAEXP / 100 AS VLR_NF,
        F4311.PDTORG AS USER,
        F5543048.CT55TRANSG AS CLASSIFICACAO_TRANSG
    FROM {{ source('jde', 'F4311') }} AS F4311
    LEFT JOIN (
        SELECT F55.* FROM {{ source('jde', 'F5543048') }} AS F55
        WHERE
            1 = 1
            AND {{ filter_remove_jde_delete_data('F55') }}
    ) AS F5543048
        ON TRIM(F5543048.CTDOCO) = TRIM(F4311.PDDOCO)
    LEFT JOIN {{ ref('uom_conversion_master') }} AS UOM
        ON
            F4311.PDLITM = UOM.ITEM
            AND F4311.PDUOM = UOM.UOMTO
    WHERE
        1 = 1
        AND F4311.PDCO IN ('52171', '52180', '52191')
        AND F4311.PDDCTO IN ('OH', 'E1')
        AND F4311.PDLNTY = 'EE'
        AND (
            {{ julian_date_to_gregorian('F4311', 'PDPDDJ') }} > ADD_MONTHS(CURRENT_DATE(), -3)
        )
        AND F4311.PDLITM IN (
            --'00001', '00100', '00002', '00027', '00034', '00026', '90584',
            --'09127', '09311', '09369', '179891', '10068'
			SELECT ITEM FROM SKU_ITEM
        )
        AND {{ filter_remove_jde_delete_data('F4311') }}
),

ONHANDS_INBOUND_OH_NOT_APPLIED AS (
    SELECT
        ORIGEM,
        FAZENDA,
        CONTRATO,
        FRETE,
        PRODUTO,
        NR_PEDIDO,
        DOC,
        LINHA,
        NR_NF,
        "STATUS",
        DATA_TRANSACAO,
        DATA_CONTABIL,
        VOLUME_NF,
        VOL_APLICADO,
        VLR_NF,
        USER,
        CLASSIFICACAO_TRANSG,
        TRIM(DESTINO) AS DESTINO,
        TRIM(ITEM) AS ITEM
    FROM CARGAS_PARADAS
    WHERE
        1 = 1
        AND STATUS = '400-420'
        AND NOT EXISTS (
            SELECT *
            FROM CARDEX_CTE
            WHERE
                1 = 1
                AND NR_PEDIDO = ILDOCO
                AND LINHA = ILLNID
                AND DESTINO = TRIM(ILMCU)
                AND VOL_CARDEX > 0
        )
),

OH_NOT_APPLIED_GROUPED AS (
    SELECT
        DESTINO,
        ITEM,
        SUM(VOLUME_NF) AS VOLUME_NF
    FROM ONHANDS_INBOUND_OH_NOT_APPLIED
    WHERE
        STATUS = '400-420'
    GROUP BY
        DESTINO,
        ITEM
),


/* ONHANDS INBOUND FINAL */
ONHANDS_INBOUND_STG AS (
    SELECT
        COALESCE(I.ITEM, 'N/A') AS ITEM,
        COALESCE(ONHANDS_SALDO.BP, 'N/A') AS BP,
        COALESCE(L.LOCATION_UNIT_ID, 'N/A') AS "LOCATION",
        COALESCE(ONHANDS_SALDO.UOM, 'N/A') AS UOM,
        CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP) AS "DAY",
        'CARGILL' AS COMPANY,
        COALESCE((ONHANDS_OH.VOLUME_NF)::DECIMAL(20, 3), 0) AS BLOCKEDQUANTITY,
        COALESCE((
            IFNULL(ONHANDS_SALDO.SALDOINICIAL,0)
            + IFNULL(ONHANDS_SALDO.RESIDUO,0)
            + IFNULL(ONHANDS_SALDO.SAIDA,0)
            + IFNULL(ONHANDS_SALDO.ENTRADA,0)
            + IFNULL(ONHANDS_SALDO.AJUSTE,0)
            + IFNULL(ONHANDS_SALDO.OUTROS_NAO_MAPEADOS,0)
        )::DECIMAL(20, 3), 0) AS ONHANDQUANTITY,
        COALESCE(
            TRIM(ONHANDS_SALDO.AJUSTE)::DECIMAL(20, 3), 0
        ) AS QUARANTINEQUANTITY
    FROM ONHANDS_SALDO_CADEX AS ONHANDS_SALDO
    LEFT JOIN OH_NOT_APPLIED_GROUPED AS ONHANDS_OH
        ON
            ONHANDS_OH.DESTINO = ONHANDS_SALDO.BP
            AND ONHANDS_OH.ITEM = ONHANDS_SALDO.PRODUTO
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS L
        ON ONHANDS_SALDO.BP = L.LOCATIONID
    INNER JOIN {{ ref('item_master') }} AS I
        ON ONHANDS_SALDO.PRODUTO = I.ITEM
    WHERE
        1 = 1
        AND L.LOCATION_UNIT_ID IS NOT NULL
        AND L.LOCATION_TYPE NOT IN ('TROCA DE NOTA FISCAL', 'FORMAÇÃO DE LOTE')
),

ONHANDS_INBOUND AS (
    /*
        Verifica se o horário da execução está dentro do horário de
        fechamento da planta. O horário de fechamento da planta será
        o valor da coluna hr_begin_onhands da tabela F_MIN_LOCATION_agrupada
        + 1 hora. Caso a hora corrente seja menor ou igual, atualiza
        esse registro, caso não, mantem o valor do registro anterior.
    */
    SELECT
        CASE
            WHEN OH_STG.ITEM IS NULL OR OH_TIME.ITEM IS NOT NULL
                THEN OH.ITEM
            ELSE OH_STG.ITEM
        END AS ITEM,
        CASE
            WHEN OH_STG.BP IS NULL OR OH_TIME.BP IS NOT NULL
                THEN OH.BP
            ELSE OH_STG.BP
        END AS BP,
        CASE
            WHEN OH_STG.LOCATION IS NULL OR OH_TIME.LOCATION IS NOT NULL
                THEN OH.LOCATION
            ELSE OH_STG.LOCATION
        END AS "LOCATION",
        CASE
            WHEN OH_STG.UOM IS NULL OR OH_TIME.UOM IS NOT NULL
                THEN OH.UOM
            ELSE OH_STG.UOM
        END AS UOM,
        CASE
            WHEN OH_STG.DAY IS NULL OR OH_TIME.DAY IS NOT NULL
                THEN TO_CHAR(OH."DAY", 'DD-MM-YYYY HH24:MI:SS')
            ELSE OH_STG.DAY
        END AS "DAY",
        CASE
            WHEN OH_STG.COMPANY IS NULL OR OH_TIME.COMPANY IS NOT NULL
                THEN OH.COMPANY
            ELSE OH_STG.COMPANY
        END AS COMPANY,
        CASE
            WHEN OH_STG.BLOCKEDQUANTITY IS NULL OR OH_TIME.BLOCKEDQUANTITY IS NOT NULL
                THEN OH.BLOCKEDQUANTITY
            ELSE OH_STG.BLOCKEDQUANTITY
        END AS BLOCKEDQUANTITY,
        CASE
            WHEN OH_STG.ONHANDQUANTITY IS NULL OR OH_TIME.ONHANDQUANTITY IS NOT NULL
                THEN OH.ONHANDQUANTITY
            ELSE OH_STG.ONHANDQUANTITY
        END AS ONHANDQUANTITY,
        CASE
            WHEN OH_STG.QUARANTINEQUANTITY IS NULL OR OH_TIME.QUARANTINEQUANTITY IS NOT NULL
                THEN OH.QUARANTINEQUANTITY
            ELSE OH_STG.QUARANTINEQUANTITY
        END AS QUARANTINEQUANTITY,
        LOC_GROUP.HR_BEGIN_ONHANDS,
        LOC_GROUP.TIMEZONE
    FROM ONHANDS_INBOUND_STG AS OH
    INNER JOIN {{ source('pscfl', 'F_MIN_LOCATION_AGRUPADA') }} AS LOC_GROUP
        ON OH.LOCATION = LOC_GROUP.UNIT_ID
    /*
        Join para recuperar as atuais informações da tabela {{ this }} e compor
        todas as colunas caso não seja o horário de atualização da planta.
    */
    LEFT JOIN TAB_ONHANDS_INBOUND AS OH_STG
        ON
            OH.ITEM = OH_STG.ITEM
            AND OH.BP = OH_STG.BP
            AND OH.LOCATION = OH_STG.LOCATION
    /*
        Join para verificar se o horário atual corresponde ao horário de
        atualização da planta.
    */
    LEFT JOIN ONHANDS_INBOUND_STG AS OH_TIME
        ON
            OH.ITEM = OH_TIME.ITEM
            AND OH.BP = OH_TIME.BP
            AND OH.LOCATION = OH_TIME.LOCATION
            /*
                Recupera a hora atual no timezone da planta analisada, e
                verifica se esse horário é igual ao horário da coluna begin
                of onhands.
            */
            AND (
                TO_TIME(DATEADD('HOUR', REPLACE(LOC_GROUP.TIMEZONE, ':00')::INT, CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP))) -- noqa
                    <= DATEADD('MINUTES', 59, TO_TIME(LOC_GROUP.HR_BEGIN_ONHANDS)) -- noqa
                OR
                TO_TIME(CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP)) -- noqa
                BETWEEN TO_TIME('09:00:00') AND TO_TIME('09:59:00') -- noqa
            )
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM ONHANDS_INBOUND
WHERE
    1 = 1
