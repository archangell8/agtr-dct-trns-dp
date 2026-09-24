{{
    config(
        materialized='view'
    )
}}
WITH
DISTRIBUTION_COST_STG AS (
    SELECT
        I.BODLANEID AS BODLANE,
        I.MONTH,
        I.ITEMID AS ITEM,
        I.DISTTRANSPORTATIONCOSTPERUNIT,
        'BRE' AS CURRENCY,
        I.TRANSMODE
    FROM {{ ref('tab_itemlane_distribution_stg') }} AS I
    WHERE I.MONTH IS NOT NULL
),

DISTRIBUTION_COST AS (
    SELECT
        COALESCE(BODLANE, 'N/A') AS BODLANE,
        COALESCE(MONTH, 'N/A') AS MONTH,
        COALESCE(ITEM, 'N/A') AS ITEM,
        COALESCE(TRANSMODE, 'N/A') AS TRANSMODE,
        COALESCE(
            DISTTRANSPORTATIONCOSTPERUNIT,
            NULL
        ) AS DISTTRANSPORTATIONCOSTPERUNIT,
        COALESCE(CURRENCY, 'N/A') AS CURRENCY
    FROM
        DISTRIBUTION_COST_STG
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM DISTRIBUTION_COST
WHERE
    1 = 1
    AND {{ date_max_filter('MONTH', 'MM-YYYY', 'na') }} --noqa
