-- noqa: disable=RF06
{{
    config(
        materialized='table'
    )
}}

WITH
CTE_UDC AS (
    SELECT
        SOURCE_CODE,
        TARGET_CODE,
        CATEGORY,
        STAGE
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
    WHERE
        1 = 1
        AND STATUS = 'ATIVO'
),

TABLE_DATE AS (
    --tabela para gerar os dias dos meses e cartesionar a query abaixo
    SELECT
        DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY NULL), '2022-12-01')
            AS DATES
    FROM TABLE(GENERATOR(ROWCOUNT => 1000000))
),

RESOURCE_CAPACITY_PSI AS (
    SELECT
        'TN' AS UOM,
        'ACTUALS' AS "TYPE",
        UPPER(PSI.SHEET) AS COMMENTS,
        TRIM(PSI.METRIC) AS CLASSIFICATION,
        REPLACE(PSI.VALUEINPUT, ',', '.') AS "VALUE",
        UPPER(RES.TARGET_CODE) AS "RESOURCE",
        --data vem da tabela de dias
        TO_DATE(DAT.DATES) AS "DAY",
        UPPER(COALESCE(LOC.TARGET_CODE, PSI.LOCATION)) AS "LOCATION"
    FROM {{ source('pscfl', 'F_MIN_PSI_IBP_ANALISEPLANTAS_CAPACIDADE') }} AS PSI
    LEFT JOIN CTE_UDC AS LOC
        ON
            PSI.LOCATION = LOC.SOURCE_CODE
            AND LOC.CATEGORY = 'RESOURCE_CAPACITY'
            AND LOC.STAGE = 'LOCATION'
    INNER JOIN CTE_UDC AS RES
        ON
            UPPER(PSI.TABLE_NAME) = RES.SOURCE_CODE
            AND RES.CATEGORY = 'RES_CAP_RESOURCE'
            AND RES.STAGE = 'CAPACITYINPUT'
    INNER JOIN TABLE_DATE AS DAT
        ON PSI.MONTH = TO_CHAR(DAT.DATES, 'MM-YYYY')
    WHERE
        1 = 1
        AND UPPER(PSI.TABLE_NAME) NOT IN (
            SELECT CTE_UDC.SOURCE_CODE
            FROM CTE_UDC
            WHERE
                CTE_UDC.CATEGORY = 'RES_CAP_FILTROS'
                AND CTE_UDC.STAGE = 'CAPACITYINPUT'
        )
),

KLAKE_STG AS (
    SELECT
        'TN' AS UOM,
        'ACTUALS' AS "TYPE",
        MASTER.EVENT_START_TIME_LOCAL::TIMESTAMP AS EVENT_START_TIME_LOCAL,
        MASTER.EVENT_END_TIME_LOCAL::TIMESTAMP AS EVENT_END_TIME_LOCAL,
        MASTER.MACHINE_TIME_LOSS_IN_MIN,
        UPPER(
            COALESCE(UDC_RES.TARGET_CODE, MASTER.EVENT_ELEMENT)
        ) AS "RESOURCE",
        COALESCE(UDC.TARGET_CODE, TRIM(UPPER(MASTER.PLANT))) AS "LOCATION",
        UPPER(
            REGEXP_SUBSTR(
                MASTER.REASON_CODE,
                '^\\\\[^\\\\]*\\\\[^\\\\]*\\\\([^\\\\]*)\\\\',
                1, 1, 'e', 1
            )
        ) AS CLASSIFICATION,
        TRIM(REGEXP_REPLACE(TRANSLATE(
            UPPER(COALESCE(MASTER.COMMENT, '')), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC'
        ), '[^A-Z0-9]', ' ')) AS "COMMENTS",
        MAX(
            CASE
                WHEN UPPER(MASTER.DYNAMIC_ATT_EVENT_VAR_NAME) = 'LOCAL LOSS'
                    THEN MASTER.DYNAMIC_ATT_EVENT_VAR_VALUE
            END
        ) AS "VALUE",
        MAX(
            CASE
                WHEN UPPER(MASTER.DYNAMIC_ATT_EVENT_VAR_NAME) = 'REASON DISPLAY TEXT' --noqa
                    THEN MASTER.DYNAMIC_ATT_EVENT_VAR_VALUE
            END
        ) AS REASON_DISPLAY_TEXT
    FROM {{ source('klake', 'SM_EVENTS') }} AS MASTER
    LEFT JOIN CTE_UDC AS UDC
        ON
            TRIM(UPPER(MASTER.PLANT)) = TRIM(UDC.SOURCE_CODE)
            AND UDC.CATEGORY = 'RESOURCE_CAPACITY'
            AND UDC.STAGE = 'LOCATION'
    LEFT JOIN CTE_UDC AS UDC_RES
        ON
            TRIM(UPPER(MASTER.EVENT_ELEMENT)) = TRIM(UDC_RES.SOURCE_CODE)
            AND UDC_RES.CATEGORY = 'RES_CAP_RESOURCE'
            AND UDC_RES.STAGE = 'CAPACITYINPUT'
    WHERE
        UPPER(MASTER.PLANT) IN (
            SELECT DISTINCT CTE_UDC.SOURCE_CODE
            FROM CTE_UDC
            WHERE
                CTE_UDC.CATEGORY = 'RESOURCE_CAPACITY'
                AND CTE_UDC.STAGE = 'LOCATION'
        )
        AND UPPER(MASTER.EVENT_ELEMENT) IN (
            'REFINERY', 'REFINERY 2', 'GLYCERIN', 'CRUSH', 'CRUSH 2'
        )
        AND TO_DATE(
            MASTER.EVENT_START_TIME_LOCAL, 'YYYY-MM-DD HH:MI:SS'
        ) >= TO_DATE('2025-05-31 00:00:00', 'YYYY-MM-DD HH:MI:SS')
        AND MASTER.EVENT_END_TIME_LOCAL IS NOT NULL
    GROUP BY
        MASTER.PLANT,
        UPPER(
            COALESCE(UDC_RES.TARGET_CODE, MASTER.EVENT_ELEMENT)
        ),
        MASTER.EVENT_START_TIME_LOCAL,
        MASTER.EVENT_END_TIME_LOCAL,
        MASTER.MACHINE_TIME_LOSS_IN_MIN,
        MASTER.EVENT_TYPE,
        UDC.TARGET_CODE,
        TRIM(REGEXP_REPLACE(TRANSLATE(
            UPPER(COALESCE(MASTER.COMMENT, '')), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC'
        ), '[^A-Z0-9]', ' ')),
        UPPER(
            REGEXP_SUBSTR(
                MASTER.REASON_CODE,
                '^\\\\[^\\\\]*\\\\[^\\\\]*\\\\([^\\\\]*)\\\\',
                1, 1, 'e', 1
            )
        )
),

RESOURCE_CAPACITY_KLAKE_STG AS (
    SELECT
        LOCATION,
        RESOURCE,
        EVENT_START_TIME_LOCAL,
        EVENT_END_TIME_LOCAL,
        MACHINE_TIME_LOSS_IN_MIN,
        VALUE,
        UOM,
        TYPE,
        CLASSIFICATION,
        COMMENTS,
        CASE
            WHEN TO_DATE(EVENT_START_TIME_LOCAL) != TO_DATE(EVENT_END_TIME_LOCAL) --noqa
                THEN
                    GREATEST(
                        DATEDIFF(
                            'minute',
                            EVENT_START_TIME_LOCAL,
                            EVENT_END_TIME_LOCAL
                        ), 0
                    )
            ELSE
                GREATEST(
                    COALESCE(TRY_TO_NUMBER(MACHINE_TIME_LOSS_IN_MIN), 0), 0
                )
        END::INT AS MACHINE_TIME_LOSS_IN_MIN_INT,
        DATEDIFF(
            'day',
            TO_DATE(EVENT_START_TIME_LOCAL),
            TO_DATE(EVENT_END_TIME_LOCAL)
        ) AS DAYS_DIFF,
        DATEDIFF(
            'minute', EVENT_START_TIME_LOCAL, EVENT_END_TIME_LOCAL
        ) AS EVENT_DURATION_MIN
    FROM KLAKE_STG
    WHERE VALUE IS NOT NULL
),

TABELA_NUMEROS_DATAS AS (
    SELECT SEQ4() AS N
    FROM TABLE(GENERATOR(ROWCOUNT => 100))
),

RESOURCE_CAPACITY_KLAKE_TRANS AS (
    SELECT
        CAPACITY.*,
        CASE
            WHEN N.N = 0
                THEN CAPACITY.EVENT_START_TIME_LOCAL
            ELSE DATEADD(DAY, N.N, TO_DATE(CAPACITY.EVENT_START_TIME_LOCAL))
        END AS EVENT_DAY,
        CASE
            WHEN N.N = 0
                THEN LEAST(
                    DATEADD(
                        MINUTE,
                        CAPACITY.MACHINE_TIME_LOSS_IN_MIN_INT::INT,
                        CAPACITY.EVENT_START_TIME_LOCAL
                    ),
                    DATEADD(DAY, 1, TO_DATE(CAPACITY.EVENT_START_TIME_LOCAL))
                )
            WHEN N.N = CAPACITY.DAYS_DIFF
                THEN CAPACITY.EVENT_END_TIME_LOCAL
            ELSE DATEADD(DAY, N.N + 1, TO_DATE(CAPACITY.EVENT_START_TIME_LOCAL))
        END AS END_OF_EVENT_DAY
    FROM RESOURCE_CAPACITY_KLAKE_STG AS CAPACITY
    INNER JOIN TABELA_NUMEROS_DATAS AS N
        ON CAPACITY.DAYS_DIFF >= N.N
),

RESOURCE_CAPACITY_KLAKE_INI AS (
    SELECT
        LOCATION,
        RESOURCE,
        CLASSIFICATION,
        UOM,
        TYPE,
        COMMENTS,
        MACHINE_TIME_LOSS_IN_MIN_INT,
        EVENT_DURATION_MIN,
        VALUE,
        TO_DATE(EVENT_DAY) AS DAY,
        DATEDIFF(
            'minute', EVENT_DAY, END_OF_EVENT_DAY
        ) AS DIFERENCA_MINUTOS
    FROM RESOURCE_CAPACITY_KLAKE_TRANS
),

RESOURCE_CAPACITY_KLAKE AS (
    SELECT
        LOCATION,
        RESOURCE,
        DAY,
        CLASSIFICATION,
        UOM,
        TYPE,
        COMMENTS,
        (
            (
                TRY_TO_NUMBER(VALUE)
                / IFF(
                    EVENT_DURATION_MIN > 0,
                    EVENT_DURATION_MIN,
                    MACHINE_TIME_LOSS_IN_MIN_INT
                )
            )::DOUBLE * DIFERENCA_MINUTOS
        ) AS "VALUE"
    FROM RESOURCE_CAPACITY_KLAKE_INI
    WHERE
        COALESCE(CLASSIFICATION, '') != ''
        AND DIFERENCA_MINUTOS > 0
),

RESOURCE_FINAL AS (
    SELECT
        'PSI' AS SOURCE,
        COALESCE(NULLIF(LOCATION, ''), 'N/A') AS "LOCATION",
        COALESCE(NULLIF(RESOURCE, ''), 'N/A') AS "RESOURCE",
        TO_CHAR(DAY, 'DD-MM-YYYY') AS "DAY",
        COALESCE(
            TRANSLATE(
                NULLIF(CLASSIFICATION, ''),
                'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC'
            ),
            'N/A'
        ) AS CLASSIFICATION,
        COALESCE(VALUE::DECIMAL(20, 3), 0.000) AS "VALUE",
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM,
        COALESCE(NULLIF(TYPE, ''), 'N/A') AS "TYPE",
        COALESCE(NULLIF(COMMENTS, ''), 'N/A') AS COMMENTS
    FROM RESOURCE_CAPACITY_PSI

    UNION DISTINCT

    SELECT
        'KLAKE' AS SOURCE,
        COALESCE(NULLIF(LOCATION, ''), 'N/A') AS "LOCATION",
        COALESCE(NULLIF(RESOURCE, ''), 'N/A') AS "RESOURCE",
        TO_CHAR(DAY, 'DD-MM-YYYY') AS "DAY",
        COALESCE(
            TRANSLATE(
                NULLIF(CLASSIFICATION, ''),
                'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC'
            ),
            'N/A'
        ) AS CLASSIFICATION,
        COALESCE(VALUE::DECIMAL(20, 3), 0.000) AS "VALUE",
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM,
        COALESCE(NULLIF(TYPE, ''), 'N/A') AS "TYPE",
        COALESCE(NULLIF(COMMENTS, ''), 'N/A') AS COMMENTS
    FROM RESOURCE_CAPACITY_KLAKE
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM RESOURCE_FINAL
WHERE
    1 = 1
    AND {{ date_max_filter('DAY', 'DD-MM-YYYY', 'na') }} --noqa
