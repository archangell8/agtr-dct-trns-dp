{{
    config(
        materialized = 'view'
    )
}}

WITH
DETAILS_TEMP AS (
    SELECT
        HEAD.ID,
        HEAD.NAME,
        HEAD.ESTIMATEDTIMEARRIVAL,
        HEAD.ESTIMATEDTIMEBERTHING,
        HEAD.ESTIMATEDTIMECOMPLETION,
        HEAD.LAYCANMIN,
        HEAD.LAYCANMAX,
        HEAD.CHARTER,
        HEAD.LOCATION,
        HEAD.DEMURRAGERATE,
        HEAD.DESPATCHRATE,
        HEAD.BUYER,
        HEAD.DESTINATION,
        PROD.ITEMID,
        PROD.PLANNEDQUANTITY,
        PROD.UOM
    FROM {{ ref('tab_vessel_stg') }} AS HEAD
    INNER JOIN {{ ref('tab_vessel_product_stg') }} AS PROD
        ON HEAD.ID = PROD.VESSELID
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM DETAILS_TEMP
WHERE
    1 = 1
    AND {{ date_max_filter('ESTIMATEDTIMEARRIVAL', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('ESTIMATEDTIMEBERTHING', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('ESTIMATEDTIMECOMPLETION', 'DD-MM-YYYY', 'na') }} --noqa
