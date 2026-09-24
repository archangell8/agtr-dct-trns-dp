-- noqa: disable=RF06
{{
    config(
        materialized = 'view'
    )
}}

WITH
QUALITY_DETAILS_TEMP AS (
    SELECT DISTINCT --noqa
        HEAD.SHIPMENTID,
        HEAD.STATUS,
        COALESCE(QLY.REFERENCEDATE, 'N/A') AS STATUSQUALITYREFERENCEDATE,
        COALESCE(QLY.MEASURE, 'N/A') AS MEASURE,
        COALESCE(QLY.VALUE, 0) AS "VALUE",
        COALESCE(QLY.UNIT, 'N/A') AS UNIT,
        HEAD.BK,
        HEAD.UOM,
        MAX(HEAD.REFERENCEDATE) AS STATUSREFERENCEDATE,
        SUM(HEAD.QUANTITY) AS QUANTITY
    FROM {{ ref('tab_shipment_status_stg') }} AS HEAD
    LEFT JOIN {{ ref('tab_shipment_status_quality_stg') }} AS QLY
        ON
            HEAD.SHIPMENTID = QLY.SHIPMENTID
            AND HEAD.STATUS = QLY.STATUS
    GROUP BY
        HEAD.SHIPMENTID,
        HEAD.STATUS,
        QLY.REFERENCEDATE,
        QLY.MEASURE,
        QLY.VALUE,
        QLY.UNIT,
        HEAD.BK,
        HEAD.UOM
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM QUALITY_DETAILS_TEMP
WHERE
    1 = 1
    AND {{ date_max_filter('STATUSQUALITYREFERENCEDATE', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('STATUSREFERENCEDATE', 'DD-MM-YYYY', 'na') }} --noqa
