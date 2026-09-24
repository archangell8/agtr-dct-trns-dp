-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH DISTRIBUTION_SNOE AS (
    SELECT
        ITEMID,
        SOURCEID,
        TRANSMODE,
        FINALDESTINATIONID,
        "DAY",
        UOM,
        OPERATOR,
        OPERATIONTYPE,
        ISBASELINE,
        CASE
            WHEN (
                TO_NUMBER(TO_CHAR(CURRENT_DATE(), 'DD')) = 1
                AND DAYOFWEEK(CURRENT_DATE()) != 1
            )
                THEN TO_CHAR(CURRENT_DATE(), 'DD-MM-YYYY')
            ELSE
                TO_CHAR(DATEADD(
                    'day', 1 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()
                ), 'DD-MM-YYYY')
        END AS REFERENCEDATE,
        SUM(PLANNEDQUANTITY) AS PLANNEDQUANTITY
    FROM {{ ref('vw_snoe_stg') }}
    GROUP BY
        ITEMID,
        SOURCEID,
        TRANSMODE,
        FINALDESTINATIONID,
        "DAY",
        UOM,
        OPERATOR,
        OPERATIONTYPE,
        ISBASELINE
),

FINAL AS (
    SELECT
        COALESCE(NULLIF(REFERENCEDATE, ''), 'N/A') AS REFERENCEDATE,
        COALESCE(NULLIF(ITEMID, ''), 'N/A') AS ITEMID,
        COALESCE(NULLIF(SOURCEID, ''), 'N/A') AS SOURCEID,
        COALESCE(NULLIF(TRANSMODE, ''), 'N/A') AS TRANSMODE,
        COALESCE(NULLIF(FINALDESTINATIONID, ''), 'N/A') AS FINALDESTINATIONID,
        COALESCE(NULLIF("DAY", ''), 'N/A') AS "DAY",
        COALESCE(PLANNEDQUANTITY::DECIMAL(18, 3), 0) AS PLANNEDQUANTITY,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM,
        COALESCE(NULLIF(OPERATOR, ''), 'N/A') AS OPERATOR,
        COALESCE(NULLIF(OPERATIONTYPE, ''), 'N/A') AS OPERATIONTYPE,
        COALESCE(NULLIF(ISBASELINE, ''), 'N/A') AS ISBASELINE
    FROM DISTRIBUTION_SNOE
    WHERE
        1 = 1
        --AND COALESCE(PLANNEDQUANTITY::DECIMAL(18, 3), 0) != 0
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM FINAL
WHERE
    1 = 1
    AND {{ date_max_filter('REFERENCEDATE','DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('DAY','DD-MM-YYYY', 'na') }} --noqa
