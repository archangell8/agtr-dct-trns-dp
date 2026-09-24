-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'referencedate', 'itemid', 'sourceid', 'transmode', 'finaldestinationid',
    'day', 'operator', 'operationtype'
] %}
{% set list_another_columns = [
    'plannedquantity', 'uom', 'isbaseline'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
DISTRIBUTION_SNOE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_distribution_snoe_stg') }}
    QUALIFY RN = 1
),

DISTRIBUTION_SNOE AS (
    SELECT
        S.REFERENCEDATE,
        S.ITEMID,
        S.SOURCEID,
        S.TRANSMODE,
        S.FINALDESTINATIONID,
        S.DAY,
        S.OPERATOR,
        S.OPERATIONTYPE,
        S.PLANNEDQUANTITY,
        S.UOM,
        S.ISBASELINE,
        S.HASH_ID
    FROM DISTRIBUTION_SNOE_STG AS S
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET FROM {{ ref('location_master') }}
        UNION
        SELECT 'ALL' AS LOCATION_IBP_ASSET
    ) AS L
        ON S.SOURCEID = L.LOCATION_IBP_ASSET
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET AS LOC FROM {{ ref('location_master') }}
        UNION
        SELECT DISTINCT LOCATIONID AS LOC FROM {{ ref('location_master') }}
    ) AS LOC2
        ON S.FINALDESTINATIONID = LOC2.LOC
    INNER JOIN (
        SELECT DISTINCT L1 AS I FROM {{ ref('item_master') }}
        UNION
        SELECT DISTINCT ITEM AS I FROM {{ ref('item_master') }}
    ) AS I
        ON S.ITEMID = I.I
    INNER JOIN (
        SELECT DISTINCT TRANSMODETYPE AS T FROM {{ ref('transmode_master') }}
        UNION ALL
        SELECT DISTINCT TRANSMODE AS T FROM {{ ref('transmode_master') }}
    ) AS T
        ON S.TRANSMODE = T.T
)

SELECT *
FROM DISTRIBUTION_SNOE
