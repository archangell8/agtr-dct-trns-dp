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
        'DATE' AS DATE, -- noqa
        'ITEM' AS ITEM,
        'SOURCE' AS SOURCE,
        'DESTINATION' AS DESTINATION,
        'SOURCINGCONTRACT' AS SOURCINGCONTRACT,
        'CARRIER' AS CARRIER,
        'TYPE' AS TYPE, -- noqa
        'TRANSPORTATIONNUMBER' AS TRANSPORTATIONNUMBER,
        'VOLUME' AS VOLUME, -- noqa
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('transportation_schedule')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('transportation_schedule')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        DATE::STRING,
        ITEM::STRING,
        SOURCE::STRING,
        DESTINATION::STRING,
        SOURCINGCONTRACT::STRING,
        CARRIER::STRING,
        TYPE::STRING,
        TRANSPORTATIONNUMBER::STRING,
        VOLUME::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('transportation_schedule') }}
)

SELECT
    DATE,
    ITEM,
    SOURCE,
    DESTINATION,
    SOURCINGCONTRACT,
    CARRIER,
    TYPE,
    TRANSPORTATIONNUMBER,
    VOLUME,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
