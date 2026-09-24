-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'vesselid', 'itemid', 'referencedate', 'date'
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
VESSEL_LOAD_BASELINE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_vessel_load_baseline_stg') }}
    QUALIFY RN = 1
),

VESSEL_LOAD_BASELINE AS (
    SELECT
        V.VESSELID,
        V.ITEMID,
        V.REFERENCEDATE,
        V.DATE,
        V.LOADEDQUANTITY,
        V.UOM,
        V.HASH_ID
    FROM VESSEL_LOAD_BASELINE_STG AS V
    INNER JOIN {{ ref('vessel_details_master') }} AS VL
        ON V.VESSELID = VL.ID
    INNER JOIN {{ ref('item_master') }} AS I
        ON V.ITEMID = I.ITEM
)

SELECT *
FROM VESSEL_LOAD_BASELINE
