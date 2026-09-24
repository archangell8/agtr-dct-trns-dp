{{
    config(
        materialized='table'
    )
}}

WITH
EMBARQUE_OTHERS AS (
    SELECT
        'P.PORTOS' AS ORIGEM,
        VESSEL_ID AS VESSELID,
        ITEMID,
        'TN' AS UOM,
        -- CHARTER AS SHIPPER,
        'CARGILL' AS SHIPPER,
        AGENCY_MERGE,
        SUM(VOLUME_TOTAL) AS PLANNEDQUANTITY
    FROM {{ ref('vw_embarque_programaportos_stg') }}
    GROUP BY
        VESSEL_ID,
        ITEMID,
        CHARTER,
        AGENCY_MERGE
),

EMBARQUE AS (
    SELECT
        ORIGEM,
        VESSELID,
        ITEMID,
        UOM,
        PLANNEDQUANTITY,
        AGENCY_MERGE
    FROM EMBARQUE_OTHERS
),

AGENCIA AS (
    SELECT
        'AGENCIA' AS ORIGEM,
        VESSEL_ID AS VESSELID,
        ITEMID,
        'TN' AS UOM,
        --CHARTER AS SHIPPER,
        AGENCY_MERGE,
        SUM(QUANTITY) AS PLANNEDQUANTITY
    FROM {{ ref('vw_agencia_maritma_stg') }}
    WHERE
        AGENCY_MERGE NOT IN (
            SELECT DISTINCT EMBARQUE.AGENCY_MERGE FROM EMBARQUE
        )
    GROUP BY
        VESSEL_ID,
        ITEMID,
        AGENCY_MERGE
),

PDF AS (
    SELECT
        'PDF' AS ORIGEM,
        P.VESSELID,
        P.ITEMID,
        P.UOM,
        TRY_CAST(REPLACE(P.PLANNEDQUANTITY, '.') AS DECIMAL(20, 3))
            AS PLANNEDQUANTITY
    FROM {{ source('pscfl', 'F_MIN_VESSELPRODUCT') }} AS P
),

VESSELPRODUCT_TEMP AS (
    SELECT
        ORIGEM,
        VESSELID,
        ITEMID,
        UOM,
        PLANNEDQUANTITY
    FROM EMBARQUE

    UNION DISTINCT

    SELECT
        ORIGEM,
        VESSELID,
        ITEMID,
        UOM,
        PLANNEDQUANTITY
    FROM AGENCIA

    UNION DISTINCT

    SELECT
        ORIGEM,
        VESSELID,
        ITEMID,
        UOM,
        PLANNEDQUANTITY
    FROM PDF
),

VESSELPRODUCT AS (
    SELECT DISTINCT
        ORIGEM,
        COALESCE(NULLIF(VESSELID, ''), 'N/A') AS VESSELID,
        COALESCE(NULLIF(ITEMID, ''), 'N/A') AS ITEMID,
        COALESCE(PLANNEDQUANTITY::DECIMAL(20, 4), 0) AS PLANNEDQUANTITY,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM
    FROM VESSELPRODUCT_TEMP
) -- #

SELECT
    *,
    HASH(*) AS HASH_ID
FROM VESSELPRODUCT
