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
        'ITEMID' AS ITEMID,
        'STARTDATE' AS STARTDATE,
        'ENDDATE' AS ENDDATE,
        'TRANSMODETYPE' AS TRANSMODETYPE,
        'DISTLOADINGCAPACITY' AS DISTLOADINGCAPACITY,
        'UOM' AS UOM,
        'LOCATION' AS LOCATION, -- noqa
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('loading_capacity')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('loading_capacity')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9 -- noqa

    UNION ALL

    SELECT
        1 AS IDX,
        ITEMID::STRING,
        STARTDATE::STRING,
        ENDDATE::STRING,
        TRANSMODETYPE::STRING,
        DISTLOADINGCAPACITY::STRING,
        UOM::STRING,
        LOCATION::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('loading_capacity') }}
)

SELECT
    ITEMID,
    STARTDATE,
    ENDDATE,
    TRANSMODETYPE,
    DISTLOADINGCAPACITY,
    UOM,
    LOCATION,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
