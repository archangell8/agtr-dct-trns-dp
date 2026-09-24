-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'ITEM' AS ITEM,
        'TRANSMODE' AS TRANSMODE,
        'BODLANE' AS BODLANE,
        'MONTH' AS MONTH, -- noqa
        'DISTTRANSPORTATIONCOSTPERUNIT' AS DISTTRANSPORTATIONCOSTPERUNIT,
        'CURRENCY' AS CURRENCY,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('distribution_cost')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('distribution_cost')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEM::STRING,
        TRANSMODE::STRING,
        BODLANE::STRING,
        MONTH::STRING,
        DISTTRANSPORTATIONCOSTPERUNIT::STRING,
        CURRENCY::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('distribution_cost') }}
)

SELECT
    ITEM,
    TRANSMODE,
    BODLANE,
    MONTH,
    DISTTRANSPORTATIONCOSTPERUNIT,
    CURRENCY,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
