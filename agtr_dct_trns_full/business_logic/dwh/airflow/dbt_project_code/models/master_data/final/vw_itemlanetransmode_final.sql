-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full', 'delta_execution'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'BODLANEID' AS BODLANEID,
        'TRANSMODE' AS TRANSMODE,
        'ITEMID' AS ITEMID,
        'LEADTIME' AS LEADTIME,
        'LOTSIZEMIN' AS LOTSIZEMIN,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('itemlanetransmode')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('itemlanetransmode')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        BODLANEID::STRING,
        TRANSMODE::STRING,
        ITEMID::STRING,
        LEADTIME::STRING,
        LOTSIZEMIN::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('itemlanetransmode') }}
)

SELECT
    BODLANEID,
    TRANSMODE,
    ITEMID,
    LEADTIME,
    LOTSIZEMIN,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
