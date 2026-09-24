-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'itemid', 'sourceid', 'finaldestinationid', 'month', 'operation',
    'type', 'transmode'
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
DISTRIBUTION_IBP_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_distribution_ibp_stg') }}
    QUALIFY RN = 1
),

DISTRIBUTION_IBP AS (
    SELECT
        S.ITEMID,
        S.SOURCEID,
        S.FINALDESTINATIONID,
        S.MONTH,
        S.OPERATION,
        S.TYPE,
        S.TRANSMODE,
        S.PLANNEDQUANTITY,
        S.UOM,
        S.HASH_ID
    FROM DISTRIBUTION_IBP_STG AS S
    INNER JOIN (
        SELECT DISTINCT TRANSMODE FROM {{ ref('transmode_master') }}
    ) AS TRANS ON TRANS.TRANSMODE = S.TRANSMODE
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET FROM {{ ref('location_master') }}
    ) AS LOC1 ON LOC1.LOCATION_IBP_ASSET = S.SOURCEID
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET FROM {{ ref('location_master') }}
    ) AS LOC2 ON LOC2.LOCATION_IBP_ASSET = S.FINALDESTINATIONID
    INNER JOIN ( --noqa
        SELECT DISTINCT L1 FROM {{ ref('item_master') }}
    ) AS ITM ON ITM.L1 = S.ITEMID
)

SELECT *
FROM DISTRIBUTION_IBP
