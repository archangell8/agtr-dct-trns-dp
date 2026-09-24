-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'demandid'
] %}
{% set list_another_columns = [
    'item', 'location', 'customerid', 'shipto', 'referenceport',
    'deliveredsalesorderquantity', 'committedsalesorderquantity',
    'creationdateofsalesorderdocument', 'salesordercommitdate',
    'lastchangeddateofsalesorder', 'uom', 'ordersalesforce', 'lta',
    'blockedquantity', 'freighttype', 'sourcebp', 'availablequantity',
    'blockingtype', 'status', 'transmode', 'operationtype', 'pickup_location'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
SALES_ORDER_DELIVERY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_sales_order_delivery_stg') }}
    QUALIFY RN = 1
),

SALES_ORDER_DELIVERY AS (
    SELECT
        S.DEMANDID,
        S.ITEM,
        S.LOCATION,
        S.SOURCEBP,
        S.CUSTOMERID,
        S.SHIPTO,
        S.REFERENCEPORT,
        S.DELIVEREDSALESORDERQUANTITY,
        S.COMMITTEDSALESORDERQUANTITY,
        S.CREATIONDATEOFSALESORDERDOCUMENT,
        S.SALESORDERCOMMITDATE,
        S.LASTCHANGEDDATEOFSALESORDER,
        S.FREIGHTTYPE,
        S.BLOCKEDQUANTITY,
        S.UOM,
        S.ORDERSALESFORCE,
        S.LTA,
        S.AVAILABLEQUANTITY,
        S.BLOCKINGTYPE,
        S.STATUS,
        S.TRANSMODE,
        S.OPERATIONTYPE,
        S.CMM_SHIPTO_ADDRESS,
        S.PICKUP_LOCATION,
        S.HASH_ID
    FROM SALES_ORDER_DELIVERY_STG AS S
    INNER JOIN {{ ref('location_master') }} AS L
        ON S.LOCATION = L.LOCATIONID
    INNER JOIN {{ ref('item_master') }} AS I
        ON S.ITEM = I.ITEM
    INNER JOIN {{ ref('customer_master') }} AS C_1
        ON S.CUSTOMERID = C_1.CUSTOMERID
)

SELECT *
FROM SALES_ORDER_DELIVERY
