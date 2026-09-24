-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH
ACTUAL_PSI_TEMP AS (
    SELECT
        ITEM,
        RESOURCEID,
        "LOCATION",
        CUSTOMERID,
        "DAY",
        VALUETYPE,
        VALUEINPUT,
        UOM
    FROM {{ ref('tab_actual_psi_ibp_shipment_stg') }}
    WHERE 1 = 2 -- noqa

    UNION DISTINCT

    SELECT
        ITEM,
        RESOURCEID,
        "LOCATION",
        'N/A' AS CUSTOMERID,
        "DAY",
        VALUETYPE,
        VALUEINPUT,
        'TN' AS UOM
    FROM {{ ref('tab_actual_psi_ibp_base_umida_stg') }}
    WHERE
        1 = 1
        AND TO_DATE("DAY", 'DD-MM-YYYY') >= '2025-01-01'
        -- AND TO_DATE("DAY", 'DD-MM-YYYY') <= '2024-08-20'
),

ACTUAL_PSI AS (
    SELECT
        ITEM,
        RESOURCEID,
        CUSTOMERID,
        "DAY",
        VALUETYPE,
        UOM,
        COALESCE(LOCATION, 'N/A') AS "LOCATION",
        SUM(COALESCE(VALUEINPUT, 0)) AS VALUEINPUT
    FROM ACTUAL_PSI_TEMP
    WHERE
        1 = 1
    GROUP BY
        ITEM,
        RESOURCEID,
        LOCATION,
        CUSTOMERID,
        "DAY",
        VALUETYPE,
        UOM
)

SELECT
    ITEM,
    RESOURCEID,
    LOCATION,
    CUSTOMERID,
    "DAY",
    VALUETYPE,
    VALUEINPUT,
    UOM,
    HASH(*) AS HASH_ID
FROM ACTUAL_PSI
WHERE
    1 = 1
    --AND COALESCE(VALUEINPUT, 0) != 0
    AND {{ date_max_filter('DAY', 'DD-MM-YYYY', 'na') }} --noqa
