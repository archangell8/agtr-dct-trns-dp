-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH VESSELLOAD AS (
    SELECT
        VESSEL_ID AS VESSELID,
        DIA AS "DATE",
        ITEMID,
        'TN' AS UOM,
        SUM(VOLUME_CARGILL) AS LOADEDQUANTITY
    FROM {{ ref('vw_embarque_programaportos_stg') }}
    GROUP BY
        VESSEL_ID,
        DIA,
        ITEMID
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM VESSELLOAD
