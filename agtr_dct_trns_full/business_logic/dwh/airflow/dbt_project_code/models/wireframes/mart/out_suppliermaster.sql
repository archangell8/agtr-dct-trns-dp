-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
SUPPLIER_MASTER AS (
    SELECT DISTINCT
        SUPPLIERID AS SUPPLIER_LOCATION,
        ADDRESS,
        COMPLEMENT,
        NEIGHBORHOOD,
        ZIPCODE,
        SUPPLIERID AS SUPPLIER,
        TAXID,
        STATUS,
        CITY,
        STATE,
        COUNTRY,
        MARKET,
        TERRITORY,
        SEGMENTATION,
        SUPPLIERGROUP,
        CREDITBLOCKED,
        'All' AS ALL_SUPPLIER,
        NULL AS SUPPLIER_LOCATION_TYPE,
        CONCAT(SUPPLIERID, ' - ', NAME) AS SUPPLIER_LOCATION_DISPLAYNAME,
        CONCAT(SUPPLIERID, ' - ', NAME) AS SUPPLIER_DISPLAYNAME
    FROM {{ ref('supplier_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SUPPLIER_MASTER
