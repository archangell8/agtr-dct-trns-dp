-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'location', 'item', 'day', 'measure'
] %}
{% set list_another_columns = [
    'value', 'unit'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ONHANDS_QUALITY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_onhands_quality_stg') }}
    QUALIFY RN = 1
),

ONHANDS_QUALITY AS (
    SELECT
        OH_QUALITY.LOCATION,
        OH_QUALITY.ITEM,
        OH_QUALITY.DAY,
        OH_QUALITY.MEASURE,
        OH_QUALITY.VALUE,
        OH_QUALITY.UNIT,
        OH_QUALITY.HASH_ID
    FROM ONHANDS_QUALITY_STG AS OH_QUALITY
    INNER JOIN (
        SELECT DISTINCT LOCATIONID FROM {{ ref('location_master') }}
    ) AS L
        ON OH_QUALITY.LOCATION = L.LOCATIONID
    INNER JOIN (
        SELECT DISTINCT ITEM FROM {{ ref('item_master') }}
    ) AS I
        ON OH_QUALITY.ITEM = I.ITEM
)

SELECT *
FROM ONHANDS_QUALITY
