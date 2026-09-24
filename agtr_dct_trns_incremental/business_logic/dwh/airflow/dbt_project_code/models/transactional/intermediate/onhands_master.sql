-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item', 'location', 'day', 'company'
] %}
{% set list_another_columns = [
    'blockedquantity', 'onhandquantity', 'quarantinequantity',
    'uom', 'cutoffquantity'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ONHANDS_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_onhands_stg') }}
    QUALIFY RN = 1
),

ONHANDS AS (
    SELECT
        ONHANDS_STG.ITEM,
        ONHANDS_STG.LOCATION,
        ONHANDS_STG.DAY,
        ONHANDS_STG.COMPANY,
        ONHANDS_STG.BLOCKEDQUANTITY,
        ONHANDS_STG.ONHANDQUANTITY,
        ONHANDS_STG.QUARANTINEQUANTITY,
        ONHANDS_STG.CUTOFFQUANTITY,
        ONHANDS_STG.UOM,
        ONHANDS_STG.HASH_ID
    FROM ONHANDS_STG AS ONHANDS_STG
    INNER JOIN {{ ref('location_master') }} AS LOC1
        ON ONHANDS_STG.LOCATION = LOC1.LOCATIONID
    INNER JOIN {{ ref('item_master') }} AS ITM
        ON ONHANDS_STG.ITEM = ITM.ITEM
)

SELECT *
FROM ONHANDS
