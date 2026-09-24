-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH VESSEL AS (
    SELECT DISTINCT
        COALESCE(NULLIF(VESSELID, ''), 'N/A') AS VESSELID,
        NULLIF(DATE, '') AS "DATE",
        COALESCE(NULLIF(ITEMID, ''), 'N/A') AS ITEMID,
        COALESCE(LOADEDQUANTITY::DECIMAL(20, 4), 0) AS LOADEDQUANTITY,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM
    FROM {{ ref('vw_embarque_vesselload_stg') }}
    WHERE TO_DATE(DATE, 'DD-MM-YYYY') >= CURRENT_DATE()
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM VESSEL
WHERE
    1 = 1
    AND {{ date_max_filter('DATE', 'DD-MM-YYYY', 'null') }} --noqa
