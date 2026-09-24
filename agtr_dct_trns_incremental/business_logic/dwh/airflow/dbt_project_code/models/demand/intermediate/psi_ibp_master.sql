-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item', 'resourceid', 'location', 'customerid', 'month', 'valuetype'
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
PSI_IBP_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_psi_ibp_stg') }}
    QUALIFY RN = 1
),

PSI_IBP AS (
    SELECT
        S.ITEM,
        S.RESOURCEID,
        S.LOCATION,
        S.CUSTOMERID,
        S.MONTH,
        S.VALUETYPE,
        S.VALUEINPUT,
        S.UOM,
        S.HASH_ID
    FROM PSI_IBP_STG AS S
    INNER JOIN (
        SELECT DISTINCT LOCATION_IBP_ASSET FROM {{ ref('location_master') }}
    ) AS L
        ON S.LOCATION = L.LOCATION_IBP_ASSET
    INNER JOIN (
        SELECT DISTINCT L1 FROM {{ ref('item_master') }}
    ) AS I
        ON S.ITEM = I.L1
    INNER JOIN (
        SELECT DISTINCT CUSTOMERID FROM {{ ref('customer_master') }}
        UNION
		SELECT 'N/A' AS CUSTOMERID
    ) AS C
        ON S.CUSTOMERID = C.CUSTOMERID
)

SELECT *
FROM PSI_IBP
