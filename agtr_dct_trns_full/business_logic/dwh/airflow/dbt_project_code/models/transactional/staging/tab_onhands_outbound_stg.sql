-- noqa: disable=RF06
{{
    config(
        materialized='table'
    )
}}

WITH
TAB_ONHANDS_OUTBOUND AS (
    /* Caso seja a primeira execução, a tabela do modelo ainda não existe */
    {% set exists_table = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.table) %} -- noqa
    {% if not exists_table %}
        SELECT
            'N/A' AS ITEM,
            'N/A' AS "LOCATION",
            'N/A' AS UOM,
            'N/A' AS "DAY",
            NULL AS COMPANY,
            NULL AS BLOCKEDQUANTITY,
            NULL AS ONHANDQUANTITY,
            NULL AS QUARANTINEQUANTITY

    /* Caso a tabela exista, referencia ela mesma */
    {% else %}
        SELECT *
        FROM {{ this }}

    {% endif %}
),

CTE_UOM_CONVERSION AS (
    SELECT
        ITEM,
        UOMFROM,
        UOMTO,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR AS FACTOR
    FROM {{ ref('uom_conversion_master') }}
),

BASE_RDS AS (
    SELECT
        RDS.CODIGOLONGOPRODUTO,
        RDS.IDBUSINESSUNIT,
        RDS.IDOPERACAOFINALIDADE,
        RDS.PESOBALANCALIQUIDO,
        RDS.QUANTIDADE,
        RDS.UNIDADEMEDIDA,
        TO_DATE(RDS.DATAHORASEGUNDAPESAGEM) AS DATAHORASEGUNDAPESAGEM,
        IFF(
            RDS.IDOPERACAOFINALIDADE = 'RECEPCAO',
            IFF(
                RDS.UNIDADEMEDIDA != 'KG',
                RDS.QUANTIDADE,
                RDS.PESOBALANCALIQUIDO
            ),
            -IFF(
                RDS.UNIDADEMEDIDA != 'KG',
                RDS.QUANTIDADE,
                RDS.PESOBALANCALIQUIDO
            )
        ) AS ONHANDQUANTITY
    FROM {{ source('rds', 'VW_RDS_HISTORIC_DCT') }} AS RDS
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LOC
        ON RDS.IDBUSINESSUNIT = LOC.LOCATIONID
    INNER JOIN {{ source('pscfl', 'F_MIN_LOCATION_AGRUPADA') }} AS LOC_GROUP
        ON LOC.LOCATION_UNIT_ID = LOC_GROUP.UNIT_ID
    WHERE
        1 = 1
        AND RDS.STATUSINTERFACEE1UPLOAD = 'S'
        AND TO_TIMESTAMP(RDS.DATAHORASEGUNDAPESAGEM) < DATEADD(
            'HOUR',
            SPLIT_PART(LOC_GROUP.HR_BEGIN_ONHANDS, ':', 1),
            DATE_TRUNC('DAY', CONVERT_TIMEZONE(
                'America/Sao_Paulo', CURRENT_TIMESTAMP()
            )::TIMESTAMP)
        )
    QUALIFY IFF(
        RDS.UNIDADEMEDIDA = 'KG',
        ROW_NUMBER() OVER (
            PARTITION BY
                RDS.FICHASEQUENCIA,
                RDS.CODIGOLONGOPRODUTO,
                RDS.IDBUSINESSUNIT
            ORDER BY RDS.DATAHORASEGUNDAPESAGEM ASC
        ) = 1
        AND ROW_NUMBER() OVER (
            PARTITION BY
                RDS.LOADE1,
                RDS.CODIGOLONGOPRODUTO,
                RDS.IDBUSINESSUNIT
            ORDER BY RDS.DATAHORASEGUNDAPESAGEM ASC
        ) = 1,
        1 = 1
    )
),

CTE_RDS AS (
    SELECT
        RDS.CODIGOLONGOPRODUTO AS ITEM,
        RDS.IDBUSINESSUNIT AS BP,
        CONV.UOMFROM AS UOM,
        SUM(RDS.ONHANDQUANTITY / CONV.FACTOR)::DECIMAL(20, 3)
            AS QUANTITY_MONTHLY_RDS,
        TO_CHAR(RDS.DATAHORASEGUNDAPESAGEM, 'MM-YYYY') AS MONTH_DATE_RDS
    FROM BASE_RDS AS RDS
    INNER JOIN CTE_UOM_CONVERSION AS CONV
        ON
            RDS.CODIGOLONGOPRODUTO = CONV.ITEM
            AND RDS.UNIDADEMEDIDA = CONV.UOMTO
    WHERE 1 = 1
    GROUP BY
        RDS.CODIGOLONGOPRODUTO,
        RDS.IDBUSINESSUNIT,
        CONV.UOMFROM,
        TO_CHAR(RDS.DATAHORASEGUNDAPESAGEM, 'MM-YYYY')
),

CTE_ACTUAL_PSI AS (
    SELECT
        ITEM,
        BP,
        TO_CHAR(TO_DATE(DAY, 'DD-MM-YYYY'), 'MM-YYYY') AS PSI_MONTH,
        SUM(
            IFF(VALUETYPE = 'PRODUCTIONINPUT', -VALUEINPUT, 0)
        ) AS PROCESSADO,
        SUM(
            IFF(VALUETYPE = 'PRODUCTIONOUTPUT', VALUEINPUT, 0)
        ) AS PRODUZIDO,
        PROCESSADO + PRODUZIDO AS PSI_QUANTITY
    FROM {{ ref('tab_actual_psi_ibp_base_umida_stg') }}
    WHERE
        1 = 1
        -- Will be used always M-1 and/or M-0 only
        AND TO_DATE(DAY, 'DD-MM-YYYY') >= DATE_TRUNC(
            'MONTH',
            DATEADD('MONTH', -1, CURRENT_DATE())
        )
        -- Don't use D0 values from actual psi
        AND TO_DATE(DAY, 'DD-MM-YYYY') < CURRENT_DATE()
    GROUP BY
        ITEM,
        BP,
        TO_CHAR(TO_DATE(DAY, 'DD-MM-YYYY'), 'MM-YYYY')
),

ASOF_TEMP AS (
    SELECT
        A.INFY,
        A.INLITM,
        TRIM(A.INMCU) AS INMCU,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06 + A.INNQ07 + A.INNQ08
        ) AS JAN,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06 + A.INNQ07 + A.INNQ08 + A.INNQ09
        ) AS FEB,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06 + A.INNQ07 + A.INNQ08 + A.INNQ09
            + A.INNQ10
        ) AS MAR,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06 + A.INNQ07 + A.INNQ08 + A.INNQ09
            + A.INNQ10 + A.INNQ11
        ) AS APR,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06 + A.INNQ07 + A.INNQ08 + A.INNQ09
            + A.INNQ10 + A.INNQ11 + A.INNQ12
        ) AS MAY,
        SUM(A.INCMQT + A.INNQ01) AS JUN,
        SUM(A.INCMQT + A.INNQ01 + A.INNQ02) AS JUL,
        SUM(A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03) AS AUG,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
        ) AS SEP,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05
        ) AS OCT,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06
        ) AS NOV,
        SUM(
            A.INCMQT + A.INNQ01 + A.INNQ02 + A.INNQ03 + A.INNQ04
            + A.INNQ05 + A.INNQ06 + A.INNQ07
        ) AS DEC
    FROM {{ source('jde', 'F41112') }} AS A
    WHERE
        1 = 1
        -- Recovery data only for actual and last harvest
        AND A.INFY IN (
            RIGHT(YEAR(CURRENT_DATE()), 2),
            RIGHT(YEAR(DATEADD('YEAR', -1, CURRENT_DATE())), 2)
        )
        AND A.INLITM NOT LIKE '% %'
    GROUP BY
        A.INFY,
        A.INLITM,
        TRIM(A.INMCU)
),

CTE_ASOF AS (
    SELECT DISTINCT
        A.INFY,
        A.INLITM,
        A.INMCU,
        A.MONTH_NUMBER::INT AS MONTH_NUMBER,
        C.UOMFROM AS UOM, --noqa
        (
            (A.MONTH_QUANTITY / 1000) / C.FACTOR  --noqa
        )::DECIMAL(20, 3) AS MONTH_QUANTITY
    FROM ASOF_TEMP AS A
    UNPIVOT ( --noqa
        MONTH_QUANTITY FOR MONTH_NUMBER IN (
            JAN AS "1",
            FEB AS "2",
            MAR AS "3",
            APR AS "4",
            MAY AS "5",
            JUN AS "6",
            JUL AS "7",
            AUG AS "8",
            SEP AS "9",
            OCT AS "10",
            NOV AS "11",
            DEC AS "12"
        )
    )
    LEFT JOIN {{ source('jde', 'F4101') }} AS B
        ON A.INLITM = B.IMLITM
    LEFT JOIN CTE_UOM_CONVERSION AS C
        ON
            B.IMLITM = C.ITEM
            AND B.IMUOM1 = C.UOMTO
),

ONHANDS_TEMP AS (
    SELECT DISTINCT
        OH.INLITM AS ITEM,
        0 AS BLOCKEDQUANTITY,
        0 AS QUARANTINEQUANTITY,
        OH.UOM,
        'CARGILL' AS COMPANY,
        LOC.LOCATION_UNIT_ID AS "LOCATION",
        CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP) AS "DAY",
        CASE
            WHEN
                DAY(CURRENT_DATE()) < 5
                AND OH.MONTH_NUMBER = MONTH(DATEADD('MONTH', -2, CURRENT_DATE())) --noqa
                THEN (
                    COALESCE(OH.MONTH_QUANTITY, 0)
                    + COALESCE(RDS_LAST_MONTH.QUANTITY_MONTHLY_RDS, 0)
                    + COALESCE(RDS_ACTUAL_MONTH.QUANTITY_MONTHLY_RDS, 0)
                    + COALESCE(PSI_LAST_MONTH.PSI_QUANTITY, 0)
                    + COALESCE(PSI_ACTUAL_MONTH.PSI_QUANTITY, 0)
                )
            WHEN
                DAY(CURRENT_DATE()) > 5
                AND OH.MONTH_NUMBER = MONTH(DATEADD('MONTH', -1, CURRENT_DATE())) --noqa
                THEN (
                    COALESCE(OH.MONTH_QUANTITY, 0)
                    + COALESCE(RDS_ACTUAL_MONTH.QUANTITY_MONTHLY_RDS, 0)
                    + COALESCE(PSI_ACTUAL_MONTH.PSI_QUANTITY, 0)
                )
        END AS ONHANDS_QUANTITY
    FROM CTE_ASOF AS OH
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LOC
        ON OH.INMCU = LOC.LOCATIONID
    INNER JOIN ITEM AS IT
        ON OH.INLITM = IT.ITEM
    LEFT JOIN CTE_RDS AS RDS_ACTUAL_MONTH
        ON
            OH.INLITM = RDS_ACTUAL_MONTH.ITEM
            AND OH.INMCU = RDS_ACTUAL_MONTH.BP
            AND RDS_ACTUAL_MONTH.MONTH_DATE_RDS = TO_CHAR(CURRENT_DATE(), 'MM-YYYY') --noqa
    LEFT JOIN CTE_RDS AS RDS_LAST_MONTH
        ON
            OH.INLITM = RDS_LAST_MONTH.ITEM
            AND OH.INMCU = RDS_LAST_MONTH.BP
            AND RDS_LAST_MONTH.MONTH_DATE_RDS = TO_CHAR(DATEADD('MONTH', -1, CURRENT_DATE()), 'MM-YYYY') --noqa
    LEFT JOIN CTE_ACTUAL_PSI AS PSI_ACTUAL_MONTH
        ON
            OH.INLITM = PSI_ACTUAL_MONTH.ITEM
            AND OH.INMCU = PSI_ACTUAL_MONTH.BP
            AND PSI_ACTUAL_MONTH.PSI_MONTH = TO_CHAR(CURRENT_DATE(), 'MM-YYYY')
    LEFT JOIN CTE_ACTUAL_PSI AS PSI_LAST_MONTH
        ON
            OH.INLITM = PSI_LAST_MONTH.ITEM
            AND OH.INMCU = PSI_LAST_MONTH.BP
            AND PSI_LAST_MONTH.PSI_MONTH = TO_CHAR(DATEADD('MONTH', -1, CURRENT_DATE()), 'MM-YYYY') --noqa
    WHERE
        1 = 1
        AND LOC.LOCATION_UNIT_STRUCTURE = 'FÁBRICA'
        AND IT.ITEMSTAGE != 'GRAOS'
        -- Only M-2 and M-1 needed from asof
        AND OH.MONTH_NUMBER BETWEEN
        MONTH(DATEADD('MONTH', -2, CURRENT_DATE()))
        AND MONTH(DATEADD('MONTH', -1, CURRENT_DATE()))
        -- change of harvest ocurrs on Month 6, but now is needed m-2 or m-1,
        -- so must still look for last harvest data
        -- On month 7, m-2 will be last harvest, and m-1 will be new harvest
        AND OH.INFY = CASE
            WHEN
                MONTH(CURRENT_DATE()) <= 6
                OR (MONTH(CURRENT_DATE()) = 7 AND DAY(CURRENT_DATE()) < 5)
                THEN TO_CHAR(EXTRACT(YEAR FROM SYSDATE()) - 2000) - 1
            WHEN MONTH(CURRENT_DATE()) >= 7
                THEN TO_CHAR(EXTRACT(YEAR FROM SYSDATE()) - 2000)
        END
),

ONHANDS_OUTBOUND_STG AS (
    SELECT
        ITEM,
        BLOCKEDQUANTITY,
        QUARANTINEQUANTITY,
        UOM,
        COMPANY,
        LOCATION,
        DAY,
        SUM(ONHANDS_QUANTITY) AS ONHANDQUANTITY
    FROM ONHANDS_TEMP
    WHERE
        1 = 1
    GROUP BY
        ITEM,
        BLOCKEDQUANTITY,
        QUARANTINEQUANTITY,
        UOM,
        COMPANY,
        LOCATION,
        DAY
),

ONHANDS_OUTBOUND AS (
    /*
        Verifica se o horário da execução está dentro do horário de
        fechamento da planta. O horário de fechamento da planta será
        o valor da coluna hr_begin_onhands da tabela F_MIN_LOCATION_agrupada
        + 1 hora. Caso a hora corrente seja menor ou igual, atualiza
        esse registro, caso não, mantem o valor do registro anterior.
    */
    SELECT -- noqa
        CASE
            WHEN OH_STG.ITEM IS NULL OR OH_TIME.ITEM IS NOT NULL
                THEN OH.ITEM
            ELSE OH_STG.ITEM
        END AS ITEM,
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
            WHEN OH_STG.BLOCKEDQUANTITY IS NULL OR OH_TIME.BLOCKEDQUANTITY IS NOT NULL -- noqa
                THEN OH.BLOCKEDQUANTITY
            ELSE OH_STG.BLOCKEDQUANTITY
        END AS BLOCKEDQUANTITY,
        CASE
            WHEN OH_STG.ONHANDQUANTITY IS NULL OR OH_TIME.ONHANDQUANTITY IS NOT NULL -- noqa
                THEN OH.ONHANDQUANTITY
            ELSE OH_STG.ONHANDQUANTITY
        END AS ONHANDQUANTITY,
        CASE
            WHEN OH_STG.QUARANTINEQUANTITY IS NULL OR OH_TIME.QUARANTINEQUANTITY IS NOT NULL -- noqa
                THEN OH.QUARANTINEQUANTITY
            ELSE OH_STG.QUARANTINEQUANTITY
        END AS QUARANTINEQUANTITY,
        LOC_GROUP.HR_BEGIN_ONHANDS,
        LOC_GROUP.TIMEZONE
    FROM ONHANDS_OUTBOUND_STG AS OH
    INNER JOIN {{ source('pscfl', 'F_MIN_LOCATION_AGRUPADA') }} AS LOC_GROUP -- noqa
        ON OH.LOCATION = LOC_GROUP.UNIT_ID
    /*
        Join para recuperar as atuais informações da tabela {{ this }} e compor
        todas as colunas caso não seja o horário de atualização da planta.
    */
    LEFT JOIN TAB_ONHANDS_OUTBOUND AS OH_STG
        ON
            OH.ITEM = OH_STG.ITEM
            AND OH.LOCATION = OH_STG.LOCATION
    /*
        Join para verificar se o horário atual corresponde ao horário de
        atualização da planta.
    */
    LEFT JOIN ONHANDS_OUTBOUND_STG AS OH_TIME
        ON
            OH.ITEM = OH_TIME.ITEM
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
FROM ONHANDS_OUTBOUND
