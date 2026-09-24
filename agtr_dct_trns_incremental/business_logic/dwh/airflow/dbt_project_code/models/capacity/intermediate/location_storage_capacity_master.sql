-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'itemid', 'locationid', 'month'
] %}
{% set list_another_columns = [
    'mincapacity', 'maxcapacity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
LOCATION_STORAGE_CAPACITY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_location_storage_capacity_stg') }}
    QUALIFY RN = 1
),

LOCATION_STORAGE_CAPACITY AS (
    SELECT
        S.LOCATIONID,
        S.MONTH,
        S.ITEMID,
        S.MINCAPACITY,
        S.MAXCAPACITY,
        S.UOM,
        S.HASH_ID
    FROM LOCATION_STORAGE_CAPACITY_STG AS S
    INNER JOIN (
        SELECT DISTINCT L1 FROM {{ ref('item_master') }}
    ) AS ITEM
        ON TRIM(ITEM.L1) = TRIM(S.ITEMID)
    INNER JOIN {{ ref('location_master') }} AS LOC
        ON LOC.LOCATIONID = S.LOCATIONID
)

SELECT *
FROM LOCATION_STORAGE_CAPACITY
