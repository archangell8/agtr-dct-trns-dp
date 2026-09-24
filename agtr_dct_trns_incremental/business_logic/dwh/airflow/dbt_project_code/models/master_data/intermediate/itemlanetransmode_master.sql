-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'bodlaneid', 'transmode', 'itemid'
] %}
{% set list_another_columns = [
    'leadtime', 'lotsizemin'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ITEM_LANE_TRANSMODE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_itemlanetransmode_stg') }}
    QUALIFY RN = 1
),

ITEM_LANE_TRANSMODE AS (
    SELECT
        S.BODLANEID,
        S.TRANSMODE,
        -- S.MODAL,
        S.ITEMID,
        S.LEADTIME,
        S.LOTSIZEMIN,
        S.HASH_ID
    FROM ITEM_LANE_TRANSMODE_STG AS S
    INNER JOIN {{ ref('lane_master') }} AS L
        ON S.BODLANEID = L.LANEID
)

SELECT *
FROM ITEM_LANE_TRANSMODE
