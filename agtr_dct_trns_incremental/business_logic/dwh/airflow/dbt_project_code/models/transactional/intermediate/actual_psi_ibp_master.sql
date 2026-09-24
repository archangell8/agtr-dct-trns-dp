-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item', 'resourceid', 'location', 'customerid', 'day', 'valuetype'
] %}
{% set list_another_columns = [
    'valueinput', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ACTUAL_PSI_IBP_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_actual_psi_ibp_stg') }}
    QUALIFY RN = 1
),

ACTUAL_PSI_IBP AS (
    SELECT
        S.ITEM,
        S.RESOURCEID,
        S.LOCATION,
        S.CUSTOMERID,
        S.DAY,
        S.VALUETYPE,
        S.VALUEINPUT,
        S.UOM,
        S.HASH_ID
    FROM ACTUAL_PSI_IBP_STG AS S
    -- INNER JOIN COM A CUSTOMER
    INNER JOIN {{ ref('item_master') }} AS ITM
        ON ITM.ITEM = S.ITEM
    INNER JOIN {{ ref('location_master') }} AS LOC
        ON S.LOCATION = LOC.LOCATIONID
)

SELECT *
FROM ACTUAL_PSI_IBP
