-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}

WITH
ACTUAL_PSI_OLD_DATA AS (
    /* values before 31-05-2026 will stay fixed becouse input bussiness logic
    on source system has changed and this data would get messed up */
    /* IF it's first execution, the model table does not exist yet */
    {% set exists_table = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.table) %}
    {% if not exists_table %}
        SELECT
            'N/A' AS COMPANY,
            'N/A' AS ITEM,
            'N/A' AS BP,
            'N/A' AS LOCATION,
            'N/A' AS RESOURCEID,
            'N/A' AS VALUETYPE,
            'N/A' AS DAY,
            NULL AS VALUEINPUT,
            NULL AS BASE_SAM_VOLUME,
            NULL AS PRODUCTION_VL,
            NULL AS REMITTANCE_PROCESS_VL,
            NULL AS CONSUMO

    /* IF the table exists, reference itself */
    {% else %}
        SELECT DISTINCT
            COMPANY,
            ITEM,
            BP,
            LOCATION,
            RESOURCEID,
            VALUETYPE,
            DAY,
            VALUEINPUT,
            BASE_SAM_VOLUME,
            PRODUCTION_VL,
            REMITTANCE_PROCESS_VL,
            CONSUMO
        FROM {{ this }}
        WHERE
            TO_DATE("DAY", 'DD-MM-YYYY') <= '2026-05-31'::DATE
    {% endif %}
),

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

CTE_UDC_RESOURCE_IM_MS AS (
    SELECT
        SPLIT_PART(SOURCE_CODE, '-', 1) AS ITEM_PROCESSADO,
        SPLIT_PART(SOURCE_CODE, '-', 2) AS ITEM_PRODUZIDO,
        TARGET_CODE AS RESOURCEID
    FROM CTE_UDC_MAPPING
    WHERE
        1 = 1
        AND CATEGORY = 'ACTUALPSI_RESOURCE'
        AND STAGE = 'IM_MS'
),

CTE_UDC_RESOURCE_IM_MS_NO_ILKIT AS (
    SELECT
        SPLIT_PART(SOURCE_CODE, '-', 1) AS BP,
        SPLIT_PART(SOURCE_CODE, '-', 2) AS ITEM_PROCESSADO,
        TARGET_CODE AS RESOURCEID
    FROM CTE_UDC_MAPPING
    WHERE
        1 = 1
        AND CATEGORY = 'ACTUALPSI_RESOURCE'
        AND STAGE = 'IM_MS_NO_ILKIT'
),

CTE_UDC_RESOURCE_IC_M1_M2 AS (
    SELECT
        SPLIT_PART(SOURCE_CODE, '-', 1) AS BP,
        SPLIT_PART(SOURCE_CODE, '-', 2) AS ITEM_PRODUZIDO,
        SPLIT_PART(SOURCE_CODE, '-', 3) AS TIPO_DOC,
        TARGET_CODE AS RESOURCEID
    FROM CTE_UDC_MAPPING
    WHERE
        1 = 1
        AND CATEGORY = 'ACTUALPSI_RESOURCE'
        AND STAGE = 'IC_M1_M2'
),

CTE_UDC_ACIDULATION AS (
    SELECT
        TRIM(SPLIT_PART(SOURCE_CODE,'-', 1)) AS ITEMID,
        TRIM(SPLIT_PART(SOURCE_CODE,'-', 2)) AS BRANCHPLANT
    FROM CTE_UDC_MAPPING
    WHERE
        CATEGORY = 'ACTUAL_PSI_ITEM_FILTER'
        AND STAGE = 'CONSUMO_REMESSA_ACIDULATION_BOM'
),

CONV AS (
    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        COALESCE(
            SUPPLYPLANNINGFINALCONVERSIONFACTOR, 1
        ) AS CONV_FACTOR
    FROM {{ ref('uom_conversion_master')}}
),

CARDEX AS (
    SELECT
        TRIM(F4111_2.ILKCO) AS ILKCO,
        TRIM(F4111_2.ILMCU) AS ILMCU,
        CASE
            -- não existe remessa para outro processo de item de Farelo,
            -- tudo é utilizado como Consumo.
            -- Lista com itens que devem ser alterados de IM para MS
            WHEN F4111_2.ILDCT = 'IM'
                AND TRIM(F4111_2.ILLITM) IN (
                    SELECT SOURCE_CODE FROM CTE_UDC_MAPPING
                    WHERE CATEGORY = 'ACTUAL_PSI_ITEM_FILTER'
                        AND STAGE = 'TRANS_IM_MS'
                )
                THEN 'MS'
            ELSE TRIM(F4111_2.ILDCT)
        END AS ILDCT,
        TRIM(F4111_2.ILLITM) AS ILLITM,
        TRIM(F4111_2.ILDGL) AS ILDGL,
        COALESCE(
            UDC_IM_MS.RESOURCEID,
            UDC_NO_ILKIT.RESOURCEID,
            UDC_IC_M1_M2.RESOURCEID
        ) AS RESOURCEID,
        SUM(
            (F4111_2.ILTRQT::DOUBLE / 1000) / CONV.CONV_FACTOR
        ) AS ILTRQT
    FROM {{ source('jde', 'F4111') }} AS F4111_2
    INNER JOIN {{ source('jde', 'F4101')}} AS F4101_2
        ON TRIM(F4111_2.ILLITM) = TRIM(F4101_2.IMLITM)
    LEFT JOIN {{ source('jde', 'F4101')}} AS F4101_ILKIT
        ON TRIM(F4111_2.ILKIT) = TRIM(F4101_ILKIT.IMITM)
    INNER JOIN CONV AS CONV
        ON
            F4111_2.ILLITM = CONV.ITEM
            AND F4111_2.ILTRUM = CONV.UOMTO
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LOC
        ON TRIM(F4111_2.ILMCU) = LOC.LOCATIONID
    INNER JOIN {{ ref('item_master') }} AS ITEM
        ON TRIM(F4111_2.ILLITM) = TRIM(ITEM.ITEM)
    /*RETORNA O RESOURCEID ATRAVÉS DO TIPO DE DOCUMENTO IM E MS,
    DESDE QUE O ILKIT SEJA PREENCHIDO*/
    /*RETORNA O RESOURCEID ATRAVÉS DO TIPO DE DOCUMENTO IM E MS,
    DESDE QUE O ILKIT SEJA PREENCHIDO*/
    LEFT JOIN CTE_UDC_RESOURCE_IM_MS AS UDC_IM_MS
        ON
            TRIM(F4111_2.ILLITM) = TRIM(UDC_IM_MS.ITEM_PROCESSADO)
            AND TRIM(F4101_ILKIT.IMLITM) = TRIM(UDC_IM_MS.ITEM_PRODUZIDO)
            AND TRIM(F4111_2.ILDCT) IN ('IM','MS')
    /*RETORNA O RESOURCEID ATRAVÉS DO TIPO DE DOCUMENTO IM E MS,
    ONDE O ILKIT NÃO ESTA PREENCHIDO*/
    LEFT JOIN CTE_UDC_RESOURCE_IM_MS_NO_ILKIT AS UDC_NO_ILKIT
        ON
            TRIM(F4111_2.ILMCU) = TRIM(UDC_NO_ILKIT.BP)
            AND TRIM(F4111_2.ILLITM) = TRIM(UDC_NO_ILKIT.ITEM_PROCESSADO)
            AND TRIM(F4111_2.ILDCT) IN ('IM','MS')
    /*RETORNA O RESOURCEID ATRAVÉS DO TIPO DE DOCUMENTO IC*/
    LEFT JOIN CTE_UDC_RESOURCE_IC_M1_M2 AS UDC_IC_M1_M2
        ON
            TRIM(F4111_2.ILMCU) = TRIM(UDC_IC_M1_M2.BP)
            AND TRIM(F4111_2.ILLITM) = TRIM(UDC_IC_M1_M2.ITEM_PRODUZIDO)
            AND TRIM(F4111_2.ILDCT) = TRIM(UDC_IC_M1_M2.TIPO_DOC)
            AND TRIM(F4111_2.ILDCT) IN ('IC', 'M1', 'M2')
    WHERE
        1 = 1
        AND TRIM(F4111_2.ILDCT) IN ('IM', 'MS', 'IC', 'M1', 'M2')
        AND TRIM(F4101_2.IMSRP0) NOT IN ('EMBALA')
        AND LOC.LOCATION_UNIT_STRUCTURE = 'FÁBRICA'
        AND ILDGL >= 126152 -- registros posteriores a 01/jun/2026
        AND COALESCE(
            UDC_IM_MS.RESOURCEID,
            UDC_NO_ILKIT.RESOURCEID,
            UDC_IC_M1_M2.RESOURCEID
        ) IS NOT NULL
        AND {{ filter_remove_jde_delete_data('F4111_2') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F4101_2') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F4101_ILKIT') }} -- noqa
    GROUP BY 1, 2, 3, 4, 5, 6
),

CONSUMO_REMESSA AS (
    SELECT
        CARDEX.ILKCO,
        CARDEX.ILLITM,
        CARDEX.ILMCU,
        CARDEX.ILDGL,
        CARDEX.ILDCT,
        CARDEX.RESOURCEID,
        'PRODUCTIONOUTPUT' AS VALUETYPE,
        SUM(
            CASE
                WHEN (
                    (UDC_ACID.ITEMID IS NOT NULL AND CARDEX.ILDCT = 'MS')
                    OR (CARDEX.ILDCT = 'IM')
                )
                    THEN CARDEX.ILTRQT
                ELSE 0
            END
        ) AS REMITTANCE_PROCESS_VL,
        SUM(
            CASE
                WHEN CARDEX.ILDCT = 'MS' AND UDC_ACID.ITEMID IS NULL
                    THEN CARDEX.ILTRQT
                ELSE 0
            END
        ) AS CONSUMED_VL
    FROM CARDEX AS CARDEX
    LEFT JOIN CTE_UDC_ACIDULATION AS UDC_ACID
        ON
            TRIM(CARDEX.ILLITM) = UDC_ACID.ITEMID
            AND TRIM(CARDEX.ILMCU) = UDC_ACID.BRANCHPLANT
    WHERE
        1 = 1
        AND TRIM(CARDEX.ILDCT) IN ('IM', 'MS')
    GROUP BY 1, 2, 3, 4, 5, 6
),

VOLUME_PROCESSADO AS (
    SELECT
        ILKCO,
        ILLITM,
        ILMCU,
        ILDGL,
        ILDCT,
        RESOURCEID,
        'PRODUCTIONINPUT' AS VALUETYPE,
        SUM(-ILTRQT) AS PROCESSED_VL
    FROM CARDEX
    WHERE 1 = 1
        AND TRIM(ILDCT) IN ('IM')
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),

VOLUME_PRODUZIDO AS (
    SELECT
        PD.ILKCO,
        PD.ILLITM,
        PD.ILMCU,
        PD.ILDGL,
        PD.RESOURCEID,
        'PRODUCTIONOUTPUT' AS VALUETYPE,
        -- PD.ILTRQT AS PRODUCED_VL,
        SUM(
            CASE
                WHEN TRIM(PD.ILDCT) IN ('IC', 'M2', 'M1')
                    THEN PD.ILTRQT
                ELSE 0
            END
        ) AS PRODUCED_VL,
        COALESCE(SUM(CR.REMITTANCE_PROCESS_VL), 0) AS REMITTANCE_PROCESS_VL,
        COALESCE(SUM(CR.CONSUMED_VL), 0) AS CONSUMED_VL
    FROM CARDEX AS PD
    LEFT JOIN CONSUMO_REMESSA AS CR
        ON PD.ILKCO = CR.ILKCO
            AND PD.ILLITM = CR.ILLITM
            AND PD.ILMCU = CR.ILMCU
            AND PD.ILDGL = CR.ILDGL
            AND PD.ILDCT = CR.ILDCT
            AND PD.RESOURCEID = CR.RESOURCEID
    WHERE
        1 = 1
        -- REMITTANCE_PROCESS_VL NOT BEING USED FOR ACTUAL MODEL,
        -- AND CAUSING UNUSED DATA
        AND TRIM(PD.ILDCT) NOT IN ('IM')
    GROUP BY 1, 2, 3, 4, 5, 6
),

ACTUAL_PSI_STG AS (
    SELECT
        ILKCO AS CIA,
        ILLITM AS ITEM,
        ILMCU AS BP,
        ILDGL AS DATA_CONTABIL,
        RESOURCEID,
        VALUETYPE,
        PRODUCED_VL + CONSUMED_VL AS VALUEINPUT,
        0 AS PROCESSED_VL,
        PRODUCED_VL,
        REMITTANCE_PROCESS_VL,
        CONSUMED_VL
    FROM VOLUME_PRODUZIDO

    UNION DISTINCT

    SELECT
        ILKCO AS CIA,
        ILLITM AS ITEM,
        ILMCU AS BP,
        ILDGL AS DATA_CONTABIL,
        RESOURCEID,
        VALUETYPE,
        PROCESSED_VL AS VALUEINPUT,
        PROCESSED_VL,
        0 AS PRODUCED_VL,
        0 AS REMITTANCE_PROCESS_VL,
        0 AS CONSUMED_VL
    FROM VOLUME_PROCESSADO
),

NEW_ACTUAL_PSI AS (
    SELECT
        STG.CIA AS COMPANY,
        STG.ITEM,
        STG.BP,
        LOC.LOCATION_UNIT_ID AS LOCATION,
        STG.RESOURCEID,
        STG.VALUETYPE,
        TO_CHAR(
            {{ julian_date_to_gregorian('STG', 'DATA_CONTABIL') }}, -- noqa
            'DD-MM-YYYY'
        ) AS DAY,
        SUM(STG.VALUEINPUT) AS VALUEINPUT,
        SUM(STG.PROCESSED_VL) AS BASE_SAM_VOLUME,
        SUM(STG.PRODUCED_VL) AS PRODUCTION_VL,
        SUM(STG.REMITTANCE_PROCESS_VL) AS REMITTANCE_PROCESS_VL,
        SUM(STG.CONSUMED_VL) AS CONSUMO
    FROM ACTUAL_PSI_STG AS STG
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS LOC
        ON STG.BP = LOC.LOCATIONID
    WHERE
        1 = 1
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),

ACTUAL_PSI_FINAL AS (
    SELECT DISTINCT
        COMPANY,
        ITEM,
        BP,
        LOCATION,
        RESOURCEID,
        VALUETYPE,
        DAY,
        VALUEINPUT::DECIMAL(20, 3) AS VALUEINPUT,
        BASE_SAM_VOLUME::DECIMAL(20, 3) AS BASE_SAM_VOLUME,
        PRODUCTION_VL::DECIMAL(20, 3) AS PRODUCTION_VL,
        REMITTANCE_PROCESS_VL::DECIMAL(20, 3) AS REMITTANCE_PROCESS_VL,
        CONSUMO::DECIMAL(20, 3) AS CONSUMO
    FROM ACTUAL_PSI_OLD_DATA

    UNION DISTINCT

    SELECT DISTINCT
        COMPANY,
        ITEM,
        BP,
        LOCATION,
        RESOURCEID,
        VALUETYPE,
        DAY,
        VALUEINPUT::DECIMAL(20, 3) AS VALUEINPUT,
        BASE_SAM_VOLUME::DECIMAL(20, 3) AS BASE_SAM_VOLUME,
        PRODUCTION_VL::DECIMAL(20, 3) AS PRODUCTION_VL,
        REMITTANCE_PROCESS_VL::DECIMAL(20, 3) AS REMITTANCE_PROCESS_VL,
        CONSUMO::DECIMAL(20, 3) AS CONSUMO
    FROM NEW_ACTUAL_PSI
    WHERE
        /* Guarantee that only new data comes from new logic*/
        TO_DATE("DAY", 'DD-MM-YYYY') > '2026-05-31'::DATE
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM ACTUAL_PSI_FINAL
