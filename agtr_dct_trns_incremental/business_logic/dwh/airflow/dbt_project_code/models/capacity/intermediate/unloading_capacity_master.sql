-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'transmodetype', 'itemid', 'location', 'startdate', 'enddate'
] %}
{% set list_another_columns = [
    'distunloadingcapacity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
UNLOADING_CAPACITY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_unloading_capacity_stg') }}
    QUALIFY RN = 1
),

UNLOADING_CAPACITY AS (
    SELECT
        S.TRANSMODETYPE,
        S.ITEMID,
        S.LOCATION,
        S.STARTDATE,
        S.ENDDATE,
        S.DISTUNLOADINGCAPACITY,
        S.UOM,
        S.HASH_ID
    FROM UNLOADING_CAPACITY_STG AS S
    INNER JOIN (--noqa
        SELECT DISTINCT TRANSMODETYPE FROM {{ ref('transmode_master') }}
    ) AS TRANS
        ON TRANS.TRANSMODETYPE = S.TRANSMODETYPE
    INNER JOIN ( --noqa
        SELECT DISTINCT ITEMSTAGE FROM {{ ref('item_master') }}
    ) AS ITEM
        ON ITEM.ITEMSTAGE = S.ITEMID
    INNER JOIN {{ ref('location_master') }} AS LOC
        ON LOC.LOCATIONID = S.LOCATION
)

SELECT *
FROM UNLOADING_CAPACITY
