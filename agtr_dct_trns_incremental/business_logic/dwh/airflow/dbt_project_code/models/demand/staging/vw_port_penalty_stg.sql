-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH PORTPENALTY_TEMP AS (
    SELECT
        V.ID AS VESSELID,
        V.ITEMID,
        D.TRANSPORT AS VESSELNAME,
        D.BL_DATE AS "DATE",
        D.CAK,
        D.ESTIMATED_VALUE AS ACTUALVALUE,
        NULL AS ESTIMATEDVALUE,
        --D.TYPE,
        'USM' AS CURRENCY,
        SUBSTR(V.ID, 1, (CHARINDEX('_', V.ID) - 1)) AS "LOCATION",
        CASE
            WHEN D.TYPE IN ('DEM', 'DEMURRAGE')
                THEN 'DEMURRAGE'
            WHEN D.TYPE IN ('DESP', 'DESPATCH')
                THEN 'DESPATCH'
            ELSE 'N/A'
        END AS "TYPE"
    FROM {{ ref('vw_demurrage_despatch_stg') }} AS D
    INNER JOIN {{ ref('vw_vessel_entire_stg') }} AS V
        ON D.MERGE_ID = V.MERGE_ID
),

PORTPENALTY AS (
    SELECT DISTINCT -- noqa
        --COALESCE(NULLIF(LOCATION, ''), 'N/A') AS "LOCATION",
        COALESCE(NULLIF(VESSELID, ''), 'N/A') AS VESSELID,
        DATE,
        COALESCE(NULLIF(ITEMID, ''), 'N/A') AS ITEMID,
        --COALESCE(NULLIF(VESSELNAME, ''), 'N/A') AS VESSELNAME,
        COALESCE(NULLIF(TYPE, ''), 'N/A') AS "TYPE",
        COALESCE(
            REPLACE(ESTIMATEDVALUE, ',', '.')::DECIMAL(20, 4),
            0
        ) AS ESTIMATEDVALUE,
        COALESCE(
            REPLACE(ACTUALVALUE, ',', '.')::DECIMAL(20, 4),
            0
        ) AS ACTUALVALUE,
        COALESCE(NULLIF(CURRENCY, ''), 'N/A') AS CURRENCY
    FROM PORTPENALTY_TEMP
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM PORTPENALTY
WHERE
    1 = 1
    AND {{ date_max_filter('DATE','DD-MM-YYYY', 'na') }} --noqa
