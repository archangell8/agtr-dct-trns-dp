-- noqa: disable=RF06
{{
    config(
        materialized='table',

        tags=['master']
    )
}}

WITH
CUSTOMER AS (
    SELECT DISTINCT
        CUSTOMERID AS CUSTOMER,
        ADDRESS,
        COMPLEMENT,
        NEIGHBORHOOD,
        ZIPCODE,
        TAXID,
        STATUS,
        CITY,
        STATE,
        COUNTRY,
        MARKET,
        TERRITORY,
        SEGMENTATION,
        CUSTOMERGROUP,
        CREDITBLOCKED,
        'All' AS ALLCUSTOMER,
        CITY AS CMM_CRUSH_CIDADEDESTINO,
        COALESCE(CONCAT(CUSTOMERID, '-', NAME), '') AS CUSTOMERDISPLAYNAME
    FROM {{ ref('customer_master') }}
)

SELECT
    *,
    CONCAT(CUSTOMERDISPLAYNAME, ' (', CITY, ')') AS CUSTOMER_CITY,
    CONCAT(CUSTOMERDISPLAYNAME, ' (', CITY, ')') AS CUSTOMER_DISPLAYNAME,
    HASH(*) AS HASH_ID
FROM CUSTOMER
