-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['onhands']
    )
}}

WITH
ONHANDS_PLANTS AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        OH.ITEM,
        OH.LOCATION,
        OH.COMPANY,
        SUM(
            OH.BLOCKEDQUANTITY + OH.ONHANDQUANTITY
        )::DECIMAL(20, 3) AS OH_QUANTITY_PLANTS,
        TO_CHAR(
            TRY_TO_DATE(OH.DAY, 'DD-MM-YYYY HH:MI:SS'),
            'DD-MON-YY'
        ) AS DAY
    FROM {{ ref('onhands_master') }} AS OH
    INNER JOIN {{ ref('location_master') }} AS LOC
        ON OH.LOCATION = LOC.LOCATIONID
    WHERE
        1 = 1
        AND OH.COMPANY = 'CARGILL'
        AND LOC.LOCATION_UNIT_STRUCTURE = 'FÁBRICA'
    GROUP BY
        OH.ITEM,
        OH.LOCATION,
        OH.COMPANY,
        TO_CHAR(
            TRY_TO_DATE(OH.DAY, 'DD-MM-YYYY HH:MI:SS'),
            'DD-MON-YY'
        )
)

SELECT
    VERSION_NAME,
    ITEM,
    LOCATION,
    COMPANY,
    DAY,
    OH_QUANTITY_PLANTS,
    HASH(*) AS HASH_ID
FROM ONHANDS_PLANTS
