-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH PORTDOWNTIME AS (
    SELECT
        COALESCE(NULLIF(LOCATION_NAME, ''), 'N/A') AS "LOCATION",
        TO_CHAR(ETB, 'DD-MM-YYYY') AS STARTDATE,
        COUNT(DISTINCT DIA) AS DURATION
    FROM {{ source('pscfl', 'F_MIN_EMBARQUE_PORTO') }}
    WHERE
        1 = 1
        AND TRANSLATE(
            UPPER(SHIPPER), 'ÁÉÍÓÚÃÕÂÊÔÇ', 'AEIOUAOAEOC'
        ) = 'MANUTENCAO'
        AND ETB IS NOT NULL
        AND ETB >= '2025-01-01 00:00:00'::TIMESTAMP
        AND ETB <= DATEADD('YEAR', 20, CURRENT_DATE())
    GROUP BY
        LOCATION_NAME,
        ETB
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM PORTDOWNTIME
