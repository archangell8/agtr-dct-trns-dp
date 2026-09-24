-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'date', 'vesselid', 'itemid'
] %}
{% set list_another_columns = [
    'loadedquantity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ACTUAL_VESSEL_LOAD_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_actual_vessel_load_stg') }}
    QUALIFY RN = 1
),

ACTUAL_VESSEL_LOAD AS (
    SELECT
        V.DATE,
        V.VESSELID,
        V.ITEMID,
        V.LOADEDQUANTITY,
        V.UOM,
        V.HASH_ID
    FROM ACTUAL_VESSEL_LOAD_STG AS V
    INNER JOIN {{ ref('vessel_details_master') }} AS VL
        ON V.VESSELID = VL.ID
    INNER JOIN {{ ref('item_master') }} AS I
        ON V.ITEMID = I.ITEM
)

SELECT *
FROM ACTUAL_VESSEL_LOAD
