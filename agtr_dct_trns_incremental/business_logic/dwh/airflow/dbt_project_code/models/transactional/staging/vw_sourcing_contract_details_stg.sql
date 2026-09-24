{{
    config(
        materialized='view',
        tags=['contracts']
    )
}}

WITH
DETAILS_TEMP AS (
    SELECT
        HEAD.ID,
        HEAD.CONTRACTNUMBER,
        HEAD.SUPPLIERID,
        HEAD.SOURCE,
        HEAD.DESTINATION,
        HEAD.DELIVERY,
        HEAD.DELIVERYUNITID,
        HEAD.ORIGINATION,
        HEAD.TRANSMODE,
        HEAD.FREIGHTTYPE,
        HEAD.DELIVERYSTART,
        HEAD.DELIVERYEND,
        HEAD.STATUS,
        HEAD.SALESREP,
        HEAD.FISCALCONDITION,
        HEAD.TYPE,
        HEAD.PAYMENTDATE,
        HEAD.PAYMENTDETAILS,
        HEAD.FARM,
        HEAD.HARVEST,
        DETAILS.ITEMID,
        DETAILS.FREIGHTCOST,
        DETAILS.ACTUALCOST,
        DETAILS.FREIGHTCADENCE,
        DETAILS.PLANNEDCOST,
        DETAILS.CURRENCY,
        DETAILS.QUANTITY,
        DETAILS.RECEIVEDQUANTITY,
        DETAILS.RECEIVEDPAF,
        DETAILS.TORECEIVETOTAL,
        DETAILS.TORECEIVEFLAT,
        DETAILS.TORECEIVEPAF,
        DETAILS.CANCELLEDQUANTITY,
        DETAILS.UOM,
        DETAILS.PRICE,
        HEAD.GLOBALINVOICE,
        HEAD.PRIORITY,
        HEAD.PURCHASEDATE,
        HEAD.ISSLIPWITHCHANGEDDESTINATION,
        HEAD.CONTRACTNUMBER_INTERNAL
    FROM {{ ref('tab_sourcing_contract_stg') }} AS HEAD
    INNER JOIN {{ ref('tab_sourcing_contract_details_stg') }} AS DETAILS
        ON HEAD.ID = DETAILS.SOURCINGCONTRACTID
    WHERE
        1 = 1
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM DETAILS_TEMP
WHERE
    1 = 1
    AND {{ date_max_filter('DELIVERYSTART', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('DELIVERYEND', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('PAYMENTDATE', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('PURCHASEDATE', 'DD-MM-YYYY', 'na') }} --noqa
