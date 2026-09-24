-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH
DEMDES AS (
    SELECT
        RESULT_TYPE AS "TYPE",
        CAK,
        UPPER(TRANSPORT) AS TRANSPORT,
        REPLACE(DEMURRAGE_RATE, ',', '.') AS DEMURRAGE_RATE,
        REPLACE(DESPATCH_RATE, ',', '.') AS DESPATCH_RATE,
        REPLACE(ESTIMATED_VALUE, ',', '.') AS ESTIMATED_VALUE,
        TO_CHAR(BL_DATE, 'DD-MM-YYYY') AS BL_DATE,
        TO_CHAR(ETA, 'DD-MM-YYYY') AS ETA,
        TO_CHAR(E_T_A, 'DD-MM-YYYY') AS E_T_A,
        TO_CHAR(ETC, 'DD-MM-YYYY') AS ETC,
        CASE
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSTEAG'  THEN '192' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSCGL'  THEN '262' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSTIP' THEN '196' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSTES' THEN '194' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'SFCOS' THEN '436' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSCOSAN' THEN '262' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'TEGRAM' THEN '86' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'SANTAREM' THEN '423' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'ART' THEN '78' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'PTUBARAO' THEN '16' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'PGUA' THEN '370' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'ITAQUI' THEN '87' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'ITAQUI/PDM' THEN '87' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STST39' THEN '191' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSTEG' THEN '193' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'RIO GRANDE' THEN '412' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'SANTOS' THEN '262' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'PARANAGUA' THEN '370' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'ARATU' THEN '78' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'TUBARAO' THEN '16' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'ITACOTIARA' THEN '1' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'SAO FRANCISCO DO SUL' THEN '436' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'BARCARENA' THEN '323' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'RGE' THEN '412' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'STSTAC' THEN '262' -- noqa
            WHEN TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC') = 'TMIB' THEN '489' -- noqa
            ELSE TRANSLATE(UPPER(PORTOS), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC')
        END AS "LOCATION",
        CASE
            WHEN UPPER(PRODUCT) = 'BRMZE' THEN '00001'
            WHEN UPPER(PRODUCT) = 'BRSBMHI' THEN '09311'
            WHEN UPPER(PRODUCT) = 'BRSBMPL' THEN '09369'
            WHEN UPPER(PRODUCT) = 'BRSBS' THEN '00027'
            WHEN UPPER(PRODUCT) = 'SBS' THEN '00027'
            WHEN UPPER(PRODUCT) = 'CORN' THEN '00001'
            ELSE UPPER(PRODUCT)
        END AS ITEMID,
        ROW_NUMBER() OVER (PARTITION BY CAK ORDER BY ETC ASC) AS RNK
    FROM {{ source('pscfl', 'F_MIN_DEMDESPACTUAL') }}
)

SELECT
    *,
    CONCAT(CAK, '|', RNK) AS MERGE_ID,
    HASH(*) AS HASH_ID
FROM DEMDES
WHERE
    CONCAT(CAK, '|', RNK) IS NOT NULL
