{{
    config(
        materialized='view'
    )
}}

WITH ECOPATIO_STATUS AS (
    SELECT
        R.*,
        ROW_NUMBER() OVER (
            PARTITION BY R.TRUCK_PLATE, R.INVOICE_NUMBER
            ORDER BY R.KAFKA_OFFSET DESC
        ) AS RNK
    FROM {{ source('ecopatio', 'STATUS_RAW_VW') }} AS R
    QUALIFY RNK = 1
)

SELECT DISTINCT -- noqa
    REPLACE(TRIM(ECO.TRUCK_PLATE), '-', '') AS VEHICLEID,
    TO_TIMESTAMP(
        IFF(
            REPLACE(
                ECO.SCHEDULE_DATE, '---', ''
            ) = '', NULL, ECO.SCHEDULE_DATE
        ),
        'DD/MM/YYYY HH24:MI:SS'
    ) AS SCHEDULEDDATE,
    TO_TIMESTAMP(
        IFF(
            REPLACE(
                ECO.DEPARTURE_DATE, '---', ''
            ) = '', NULL, ECO.DEPARTURE_DATE
        ),
        'DD/MM/YYYY HH24:MI:SS'
    ) AS DEPARTUREDATE,
    ECO.INVOICE_NUMBER AS NUM_NF
FROM
    ECOPATIO_STATUS AS ECO
WHERE
    ECO.TRUCK_PLATE IS NOT NULL
