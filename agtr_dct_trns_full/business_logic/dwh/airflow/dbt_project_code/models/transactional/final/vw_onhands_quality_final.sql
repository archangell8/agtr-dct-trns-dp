-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full', 'delta_onhands'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'LOCATION' AS LOCATION, -- noqa
        'ITEM' AS ITEM,
        'DAY' AS DAY, -- noqa
        'MEASURE' AS MEASURE,
        'VALUE' AS VALUE, -- noqa
        'UNIT' AS UNIT,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('onhands_quality')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('onhands_quality')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        LOCATION::STRING,
        ITEM::STRING,
        DAY::STRING,
        MEASURE::STRING,
        VALUE::STRING,
        UNIT::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('onhands_quality') }}
)

SELECT
    LOCATION,
    ITEM,
    DAY,
    MEASURE,
    VALUE,
    UNIT,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
