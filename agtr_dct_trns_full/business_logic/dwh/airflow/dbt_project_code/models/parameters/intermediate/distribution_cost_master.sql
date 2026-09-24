-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'bodlane', 'month', 'item', 'currency'
] %}
{% set list_another_columns = [
    'disttransportationcostperunit'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
DISTRIBUTION_COST_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_distribution_cost_stg') }}
    QUALIFY RN = 1
),

DISTRIBUTION_COST AS (
    SELECT
        DIS.BODLANE,
        DIS.MONTH AS "MONTH",
        DIS.ITEM,
        DIS.CURRENCY,
        DIS.TRANSMODE,
        DIS.DISTTRANSPORTATIONCOSTPERUNIT,
        DIS.HASH_ID
    FROM DISTRIBUTION_COST_STG AS DIS
    INNER JOIN (
        SELECT DISTINCT L2 FROM {{ ref('item_master') }}
    ) AS ITEM
        ON ITEM.L2 = DIS.ITEM
    INNER JOIN {{ ref('transmode_master') }} AS TRA
        ON TRA.TRANSMODE = DIS.TRANSMODE
    INNER JOIN {{ ref('lane_master') }} AS LANE
        ON LANE.LANEID = DIS.BODLANE
)

SELECT *
FROM DISTRIBUTION_COST
