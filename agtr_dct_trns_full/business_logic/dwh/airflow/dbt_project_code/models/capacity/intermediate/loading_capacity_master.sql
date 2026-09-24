-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'itemid', 'startdate', 'enddate', 'transmodetype', 'location'
] %}
{% set list_another_columns = [
    'distloadingcapacity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
LOADING_CAPACITY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_loading_capacity_stg') }}
    QUALIFY RN = 1
),

LOADING_CAPACITY AS (
    SELECT
        S.ITEMID,
        S.STARTDATE,
        S.ENDDATE,
        S.TRANSMODETYPE,
        S.LOCATION,
        S.DISTLOADINGCAPACITY,
        S.UOM,
        S.HASH_ID
    FROM LOADING_CAPACITY_STG AS S
    INNER JOIN ( --noqa
        SELECT DISTINCT L2 FROM {{ ref('item_master') }}
    ) AS ITEM
        ON ITEM.L2  = S.ITEMID
    INNER JOIN (--noqa
        SELECT DISTINCT TRANSMODETYPE FROM {{ ref('transmode_master') }}
    ) AS TRANS
        ON TRANS.TRANSMODETYPE = S.TRANSMODETYPE
    INNER JOIN {{ ref('location_master') }} AS LOC
        ON LOC.LOCATIONID = S.LOCATION
)

SELECT *
FROM LOADING_CAPACITY
