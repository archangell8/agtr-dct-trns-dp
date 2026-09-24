-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'supplierid'
] %}
{% set list_another_columns = [
    'taxid', 'name', 'status', 'address', 'complement', 'neighborhood',
    'zipcode', 'city', 'state', 'country', 'market', 'territory',
    'segmentation', 'suppliergroup', 'suppliergroupdescription',
    'creditblocked'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
SUPPLIER_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_supplier_stg') }}
    QUALIFY RN = 1
),

SUPPLIER AS (
    SELECT
        S.SUPPLIERID,
        S.TAXID,
        S.NAME AS "NAME",
        S.STATUS AS "STATUS",
        S.ADDRESS AS "ADDRESS",
        S.COMPLEMENT,
        S.NEIGHBORHOOD,
        S.ZIPCODE,
        S.CITY,
        S.STATE AS "STATE",
        S.COUNTRY,
        S.MARKET,
        S.TERRITORY,
        S.SEGMENTATION,
        S.SUPPLIERGROUP,
        S.SUPPLIERGROUPDESCRIPTION,
        S.CREDITBLOCKED::BOOLEAN AS CREDITBLOCKED,
        S.HASH_ID
    FROM SUPPLIER_STG AS S
)

SELECT *
FROM SUPPLIER
