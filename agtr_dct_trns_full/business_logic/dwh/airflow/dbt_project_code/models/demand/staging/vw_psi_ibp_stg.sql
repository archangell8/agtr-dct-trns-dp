-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH PSI_IBP_TEMP AS (
    SELECT
        ITEM,
        RESOURCEID,
        "LOCATION",
        CUSTOMERID,
        "MONTH",
        VALUETYPE,
        VALUEINPUT,
        UOM
    FROM {{ ref('vw_psi_ibp_analiseplantas_stg') }}
    WHERE
        "MONTH" != 'nan'
        AND CUSTOMERID != 'ME'
    UNION ALL
    SELECT
        ITEM,
        RESOURCEID,
        "LOCATION",
        CUSTOMERID,
        "MONTH",
        VALUETYPE,
        VALUEINPUT,
        UOM
    FROM {{ ref('vw_psi_ibp_grains_stg') }}
),

PSI_IBP AS (
    SELECT DISTINCT
        COALESCE(NULLIF(ITEM, ''), 'N/A') AS ITEM,
        COALESCE(NULLIF(RESOURCEID, ''), 'N/A') AS RESOURCEID,
        COALESCE(NULLIF(LOCATION, ''), 'N/A') AS "LOCATION",
        COALESCE(NULLIF(CUSTOMERID, ''), 'N/A') AS CUSTOMERID,
        COALESCE(NULLIF("MONTH", ''), 'N/A') AS "MONTH",
        COALESCE(NULLIF(VALUETYPE, ''), 'N/A') AS VALUETYPE,
        COALESCE(
            REPLACE(VALUEINPUT, 'N/A', '0')::DECIMAL(20, 3),
            0.000
        ) AS VALUEINPUT,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM
    FROM PSI_IBP_TEMP
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM PSI_IBP
WHERE
    1 = 1
    -- AND VALUEINPUT != 0
    AND {{ date_max_filter('MONTH', 'MM-YYYY', 'na') }} --noqa
