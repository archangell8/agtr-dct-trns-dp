-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'customerid'
] %}
{% set list_another_columns = [
        'taxid', 'name', 'status', 'address', 'complement',
        'neighborhood', 'zipcode', 'city', 'state', 'country', 'market',
        'territory', 'segmentation', 'customergroup',
        'customergroupdescription', 'creditblocked'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
CUSTOMER_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_customer_stg') }}
    QUALIFY RN = 1
),

CUSTOMER AS (
    SELECT
        S.CUSTOMERID,
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
        S.CUSTOMERGROUP,
        S.CUSTOMERGROUPDESCRIPTION,
        S.CREDITBLOCKED::BOOLEAN AS CREDITBLOCKED,
        S.HASH_ID
    FROM CUSTOMER_STG AS S
)

SELECT *
FROM CUSTOMER
