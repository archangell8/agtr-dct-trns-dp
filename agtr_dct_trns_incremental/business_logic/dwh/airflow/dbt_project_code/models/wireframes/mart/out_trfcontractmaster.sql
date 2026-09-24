-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
TRF_CONTRACT_TEMP AS (
    SELECT
        CONTRACTID,
        CONTRACTID AS ID,
        CONTRACTLINEID,
        DESTINATION,
        ITEM,
        PICKUP,
        TRANSMODE,
        'All' AS ALL_CONTRACT,
        'Origination Contract' AS CONTRACT_TYPE,
        'Active' AS CONTRACT_STATUS,
        '05-Jan-25' AS START_DATE,
        '31-Dec-99' AS END_DATE,
        'Active' AS STATUS,
        'TRF' AS FREIGHT_TYPE,
        'N/A' AS FARM,
        'N/A' AS FISCAL_CONDITION,
        'TRF' AS "TYPE",
        'N/A' AS PRODUCER,
        'N/A' AS SCHEDULING_STATUS,
        '1000000000' AS QUANTITY,
        '1000000000' AS PURCHASED,
        MAX(DAY) AS LASTDATEOFSCHEDULEDGENERATED
    FROM {{ ref('intstg_createtrfcontracts') }}
    GROUP BY
        CONTRACTID,
        CONTRACTLINEID,
        DESTINATION,
        ITEM,
        PICKUP,
        TRANSMODE
),

TRF_CONTRACT AS (
    SELECT
        CONTRACTID,
        CONTRACTLINEID,
        ID,
        DESTINATION,
        ITEM,
        PICKUP,
        TRANSMODE,
        ALL_CONTRACT,
        CONTRACT_TYPE,
        CONTRACT_STATUS,
        START_DATE,
        END_DATE,
        STATUS,
        FREIGHT_TYPE,
        FARM,
        FISCAL_CONDITION,
        TYPE,
        PRODUCER,
        SCHEDULING_STATUS,
        QUANTITY::DECIMAL(20, 3) AS QUANTITY,
        PURCHASED::DECIMAL(20, 3) AS PURCHASED,
        TO_CHAR(
            LASTDATEOFSCHEDULEDGENERATED, 'DD-MON-YY'
        ) AS LASTDATEOFSCHEDULEDGENERATED
    FROM TRF_CONTRACT_TEMP
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM TRF_CONTRACT
