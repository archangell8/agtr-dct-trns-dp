-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'itemid', 'sourceid', 'transmode', 'finaldestinationid', 'day',
    'operator', 'operationtype'
] %}
{% set list_another_columns = [
    'plannedquantity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ACTUAL_SNOE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_actual_snoe_stg') }}
    QUALIFY RN = 1
),

ACTUAL_SNOE AS (
    SELECT
        S.ITEMID,
        S.SOURCEID,
        S.TRANSMODE,
        S.FINALDESTINATIONID,
        S.DAY,
        S.OPERATOR,
        S.OPERATIONTYPE,
        S.PLANNEDQUANTITY,
        S.UOM,
        S.HASH_ID
    FROM ACTUAL_SNOE_STG AS S
    INNER JOIN (
        SELECT DISTINCT TRANSMODETYPE AS T FROM {{ ref('transmode_master') }}
        UNION ALL
        SELECT DISTINCT TRANSMODE AS T FROM {{ ref('transmode_master') }}
    ) AS T2
        ON S.TRANSMODE = T2.T
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET FROM {{ ref('location_master') }}
        UNION ALL
        SELECT 'ALL' AS LOCATION_IBP_ASSET
    ) AS LOC1
        ON S.SOURCEID = LOC1.LOCATION_IBP_ASSET
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET AS LOC FROM {{ ref('location_master') }}
        UNION
        SELECT DISTINCT LOCATIONID AS LOC FROM {{ ref('location_master') }}
    ) AS LOC2
        ON S.FINALDESTINATIONID = LOC2.LOC
    INNER JOIN (
        SELECT DISTINCT L1 FROM {{ ref('item_master') }}
    ) AS I
        ON S.ITEMID = I.L1
)

SELECT *
FROM ACTUAL_SNOE
