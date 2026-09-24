-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'itemid'
] %}
{% set list_another_columns = [
    'name', 'estimatedtimearrival', 'estimatedtimeberthing',
    'estimatedtimecompletion', 'laycanmin', 'laycanmax', 'charter',
    'location', 'demurragerate', 'despatchrate', 'buyer', 'destination',
    'plannedquantity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
VESSEL_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_vessel_details_stg') }}
    QUALIFY RN = 1
),

VESSEL AS (
    SELECT DISTINCT
        V.ID,
        V.NAME,
        V.ESTIMATEDTIMEARRIVAL,
        V.ESTIMATEDTIMEBERTHING,
        V.ESTIMATEDTIMECOMPLETION,
        V.LAYCANMIN,
        V.LAYCANMAX,
        V.CHARTER,
        V.LOCATION,
        V.DEMURRAGERATE,
        V.DESPATCHRATE,
        V.BUYER,
        V.DESTINATION,
        V.ITEMID,
        V.PLANNEDQUANTITY,
        V.UOM,
        V.HASH_ID
    FROM VESSEL_STG AS V
    INNER JOIN {{ ref('location_master') }} AS L
        ON V.LOCATION = L.LOCATIONID
    INNER JOIN {{ ref('item_master') }} AS I
        ON V.ITEMID = I.ITEM
)

SELECT *
FROM VESSEL
