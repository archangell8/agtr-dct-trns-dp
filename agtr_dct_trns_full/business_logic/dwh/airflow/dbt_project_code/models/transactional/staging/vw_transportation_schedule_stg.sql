-- noqa: disable=RF06,ST09
{{
    config(
        materialized='view'
    )
}}

WITH
CMM_DAY_OF_WEEK AS (
    SELECT
        *,
        'SEG' AS DAY_OF_WEEK,
        DATEADD(DAY, 1 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_SEGUNDA AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_SEGUNDA != '0'

    UNION ALL

    SELECT
        *,
        'TER' AS DAY_OF_WEEK,
        DATEADD(DAY, 2 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_TERCA AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_TERCA != '0'

    UNION ALL

    SELECT
        *,
        'QUA' AS DAY_OF_WEEK,
        DATEADD(DAY, 3 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_QUARTA AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_QUARTA != '0'

    UNION ALL

    SELECT
        *,
        'QUI' AS DAY_OF_WEEK,
        DATEADD(DAY, 4 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_QUINTA AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_QUINTA != '0'

    UNION ALL

    SELECT
        *,
        'SEX' AS DAY_OF_WEEK,
        DATEADD(DAY, 5 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_SEXTA AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_SEXTA != '0'

    UNION ALL

    SELECT
        *,
        'SAB' AS DAY_OF_WEEK,
        DATEADD(DAY, 6 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_SABADO AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_SABADO != '0'

    UNION ALL

    SELECT
        *,
        'DOM' AS DAY_OF_WEEK,
        DATEADD(DAY, 7 - DAYOFWEEK(FIRSTDAYOFWEEK), FIRSTDAYOFWEEK) AS DT,
        VOL_DOMINGO AS "VOLUME"
    FROM {{ ref('tab_cmm_stg') }}
    WHERE
        1 = 1
        AND VOL_DOMINGO != '0'
),

FINALDESTINATION_LOCATION AS (
    SELECT DISTINCT
        LOCATION_UNIT_ID,
        LOCATION_NAME
    FROM {{ ref('tab_location_internal_stg') }}
),

TRANSPORTATION_SCHEDULE_STG AS (
    SELECT DISTINCT -- noqa: disable=ST06
        CMM.ID_CMM,
        CMM.ADDRESS_TRANSPORTADORA,
        CMM.SALESOP AS SALESORDERDELIVERYID,
        COALESCE(
            TO_CHAR(CMM.DT, 'DD-MM-YYYY'), 'N/A'
        ) AS "DATE",
        COALESCE(NULLIF(CMM.PRODUCT_JDE::STRING, ''), 'N/A') AS ITEM,
        /* CASO TRF CONSIDERAR BP, POIS A ORIGEM É UM ARMAZÉM DA CARGILL */
        CASE
            WHEN CMM.TIPO_OPERACAO = 'TRF'
                THEN COALESCE(NULLIF(LOC_3.LOCATION_UNIT_ID, ''), 'N/A')
            ELSE COALESCE(NULLIF(LOC_1.LOCATION_UNIT_ID, ''), 'N/A')
        END AS SOURCE,
        CASE
            WHEN NULLIF(TRIM(CMM.SALES_TYPE), '') IS NOT NULL
                THEN COALESCE(SOD.SHIPTO, 'N/A')
            ELSE COALESCE(NULLIF(LOC_2.LOCATION_UNIT_ID, ''), 'N/A')
        END AS DESTINATION,
        COALESCE(
            NULLIF(SCD_1.ID, ''), NULLIF(SCD_2.ID, ''), NULLIF(SC.ID, ''), 'N/A'
        ) AS SOURCINGCONTRACT,
        COALESCE(
            NULLIF(
                CONCAT(CMM.ADDRESS_TRANSPORTADORA, ' - ', CMM.TRASPORTADORA), ''
            ), '00000000 - TRANSPORTADORA NAO INFORMADA'
        ) AS CARRIER,
        CASE
            WHEN NULLIF(TRIM(CMM.SALES_TYPE), '') IS NOT NULL THEN 'VEN'
            ELSE COALESCE(NULLIF(CMM.TIPO_OPERACAO, ''), 'N/A')
        END AS "TYPE",
        CONCAT(
            CMM.TN_NUMBER::STRING, '-', SUBSTR(CMM.ROTA, 4, 2)
        ) AS TRANSPORTATIONNUMBER,
        REPLACE(CMM.VOLUME, ',', '.')::DECIMAL(20, 3) AS "VOLUME",
        CASE
            WHEN NULLIF(TRIM(CMM.SALES_TYPE), '') IS NOT NULL
                THEN CONCAT(CMM.TN_NUMBER, ' - ', CMM.SALES_NUMBER)
            ELSE CMM.TN_NUMBER
        END AS TN,
        CMM.ROTA,
        CMM.LOCAL_DESCARGA,
        COALESCE(NULLIF(CMM.CONTRACT_NUMBER, ''), 'N/A') AS CONTRACT_NUMBER,
        CMM.BP_DESTINO,
        CMM.ADDRESS_COLETA,
        LOC_5.LOCATION_UNIT_ID AS FINALDESTINATION
    FROM CMM_DAY_OF_WEEK AS CMM
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS LOC_1
        ON LOC_1.LOCATIONID = CMM.ADDRESS_COLETA
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS LOC_2
        ON LOC_2.LOCATIONID = CMM.BP_DESTINO
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS LOC_3
        ON LOC_3.LOCATIONID = CMM.BP_ORIGEM
    LEFT JOIN {{ ref('tab_location_internal_stg') }} AS LOC_4
        ON
            TRIM(SPLIT_PART(CMM.LOCAL_DESCARGA, '-', 0)) = LOC_4.LOCATION_NAME
            AND LOC_4.LOCATION_UNIT_STRUCTURE IN (
                'PORTO MARÍTIMO', 'TRANSBORDO', 'FÁBRICA', 'MERCADO INTERNO'
            )
            AND LEFT(CMM.BP_DESTINO, 5) = LEFT(LOC_4.LOCATIONID, 5)
    LEFT JOIN FINALDESTINATION_LOCATION AS LOC_5
        ON
            TRIM(CMM.DESTINATION) = LOC_5.LOCATION_NAME
    LEFT JOIN {{ ref('sourcing_contract_details_master') }} AS SCD_1
        ON
            SCD_1.CONTRACTNUMBER_INTERNAL = CMM.CONTRACT_NUMBER
            AND SCD_1.DESTINATION = LOC_2.LOCATION_CODE
    LEFT JOIN {{ ref('sourcing_contract_details_master') }} AS SCD_2
        ON
            SCD_2.CONTRACTNUMBER_INTERNAL = CMM.CONTRACT_NUMBER
            AND SCD_2.DESTINATION = LOC_4.LOCATION_CODE
    LEFT JOIN {{ ref('tab_sourcing_contract_internal_stg') }} AS SC
        ON CMM.CONTRACT_NUMBER = SC.CONTRACTNUMBER
    LEFT JOIN {{ ref('sales_order_delivery_master') }} AS SOD
        ON LEFT(SOD.DEMANDID, LENGTH(SOD.DEMANDID) - 12) = CMM.SALES_NUMBER
),

TRANSPORTATION_SCHEDULE AS (
    SELECT
        DATE,
        ITEM,
        SOURCE,
        DESTINATION,
        SOURCINGCONTRACT,
        CARRIER,
        TYPE,
        CONTRACT_NUMBER,
        SALESORDERDELIVERYID,
        CASE
            WHEN TYPE = 'VEN' THEN DESTINATION
            ELSE COALESCE(FINALDESTINATION, DESTINATION)
        END AS FINALDESTINATION,
        MAX(BP_DESTINO) AS BP_DESTINO,
        MAX(ADDRESS_COLETA) AS ADDRESS_COLETA,
        MAX(LOCAL_DESCARGA) AS LOCAL_DESCARGA,
        MIN(TRANSPORTATIONNUMBER) AS TRANSPORTATIONNUMBER,
        SUM(VOLUME) AS "VOLUME"
    FROM TRANSPORTATION_SCHEDULE_STG
    GROUP BY
        DATE,
        ITEM,
        SOURCE,
        DESTINATION,
        SOURCINGCONTRACT,
        CARRIER,
        TYPE,
        CONTRACT_NUMBER,
        SALESORDERDELIVERYID,
        CASE
            WHEN TYPE = 'VEN' THEN DESTINATION
            ELSE COALESCE(FINALDESTINATION, DESTINATION)
        END
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM TRANSPORTATION_SCHEDULE
WHERE
    1 = 1
    AND {{ date_max_filter('DATE', 'DD-MM-YYYY', 'na') }} --noqa
