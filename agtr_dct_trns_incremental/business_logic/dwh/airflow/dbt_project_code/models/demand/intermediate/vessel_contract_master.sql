-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'location', 'month', 'item', 'type'
] %}
{% set list_another_columns = [
    'uom', 'value'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
VESSEL_CONTRACT_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_vessel_contract_stg') }}
    QUALIFY RN = 1
),

VESSEL_CONTRACT AS (
    SELECT
        S.LOCATION,
        S.MONTH,
        S.ITEM,
        S.VALUE,
        S.UOM,
        S.TYPE,
        S.HASH_ID
    FROM VESSEL_CONTRACT_STG AS S
    INNER JOIN {{ ref('item_master') }} AS I
        ON S.ITEM = I.ITEM
    INNER JOIN {{ ref('location_master') }} AS L
        ON S.LOCATION = L.LOCATIONID
)

SELECT *
FROM VESSEL_CONTRACT
