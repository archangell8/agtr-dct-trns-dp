-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH DISTRIBUTION_OPERATIONAL AS (
    SELECT
        ITEMID,
        SOURCEID,
        TRANSMODE,
        FINALDESTINATIONID,
        "DAY",
        UOM,
        OPERATOR,
        OPERATIONTYPE,
        SUM(PLANNEDQUANTITY) AS PLANNEDQUANTITY
    FROM {{ ref('vw_snoe_stg') }}
    WHERE TO_DATE("DAY", 'DD-MM-YYYY') >= CURRENT_DATE()
    GROUP BY
        ITEMID,
        SOURCEID,
        TRANSMODE,
        FINALDESTINATIONID,
        "DAY",
        UOM,
        OPERATOR,
        OPERATIONTYPE
)

SELECT
    ITEMID,
    SOURCEID,
    TRANSMODE,
    FINALDESTINATIONID,
    "DAY",
    PLANNEDQUANTITY::DECIMAL(18, 3) AS PLANNEDQUANTITY,
    UOM,
    OPERATOR,
    OPERATIONTYPE,
    HASH(*) AS HASH_ID
FROM DISTRIBUTION_OPERATIONAL
WHERE
    1 = 1
    --AND PLANNEDQUANTITY::DECIMAL(18, 3) != 0
    AND {{ date_max_filter('DAY', 'DD-MM-YYYY', 'na') }} --noqa
