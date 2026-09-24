-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'itemid'
] %}
{% set list_another_columns = [
    'contractnumber', 'supplierid', 'source', 'farm', 'destination',
    'delivery', 'deliveryunitid', 'origination', 'transmode',
    'freighttype', 'deliverystart', 'deliveryend', 'status',
    'fiscalcondition', 'type', 'paymentdate', 'paymentdetails',
    'salesrep', 'freightcost', 'actualcost', 'freightcadence', 'plannedcost',
    'currency', 'quantity', 'receivedquantity', 'receivedpaf', 'toreceivetotal',
    'toreceiveflat', 'toreceivepaf', 'cancelledquantity', 'uom', 'price',
    'globalinvoice', 'harvest', 'priority', 'purchasedate',
    'isslipwithchangeddestination', 'contractnumber_internal'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
SOURCING_CONTRACT_DETAILS_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_sourcing_contract_details_stg') }}
    QUALIFY RN = 1
),

SOURCING_CONTRACT_DETAILS AS (
    SELECT
        S.ID,
        S.CONTRACTNUMBER,
        S.SUPPLIERID,
        S.SOURCE,
        S.DESTINATION,
        S.DELIVERY,
        S.DELIVERYUNITID,
        S.ORIGINATION,
        S.TRANSMODE,
        S.FREIGHTTYPE,
        S.DELIVERYSTART,
        S.DELIVERYEND,
        S.STATUS,
        S.SALESREP,
        S.FISCALCONDITION,
        S.TYPE,
        S.PAYMENTDATE,
        S.PAYMENTDETAILS,
        S.FARM,
        S.HARVEST,
        S.ITEMID,
        S.FREIGHTCOST,
        S.ACTUALCOST,
        S.FREIGHTCADENCE,
        S.PLANNEDCOST,
        S.CURRENCY,
        S.QUANTITY,
        S.RECEIVEDQUANTITY,
        S.RECEIVEDPAF,
        S.TORECEIVETOTAL,
        S.TORECEIVEFLAT,
        S.TORECEIVEPAF,
        S.CANCELLEDQUANTITY,
        S.UOM,
        S.PRICE,
        S.GLOBALINVOICE,
        S.PRIORITY,
        S.PURCHASEDATE,
        S.ISSLIPWITHCHANGEDDESTINATION,
        S.CONTRACTNUMBER_INTERNAL,
        S.HASH_ID
    FROM SOURCING_CONTRACT_DETAILS_STG AS S
    INNER JOIN {{ ref('item_master') }} AS ITM
        ON S.ITEMID = ITM.ITEM
    INNER JOIN {{ ref('location_master') }} AS LOC1
        ON S.SOURCE = LOC1.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LOC2
        ON S.DELIVERYUNITID = LOC2.LOCATIONID
    INNER JOIN {{ ref('supplier_master') }} AS SUP
        ON S.SUPPLIERID = SUP.SUPPLIERID
    INNER JOIN {{ ref('transmode_master') }} AS TRANS
        ON S.TRANSMODE = TRANS.TRANSMODE
    INNER JOIN {{ ref('location_master') }} AS LOC3
        ON S.FARM = LOC3.LOCATIONID
)

SELECT *
FROM SOURCING_CONTRACT_DETAILS
