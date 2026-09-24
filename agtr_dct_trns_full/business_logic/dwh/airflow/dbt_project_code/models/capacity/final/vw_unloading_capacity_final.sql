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
        'TRANSMODETYPE' AS TRANSMODETYPE,
        'ITEMID' AS ITEMID,
        'LOCATION' AS LOCATION, --noqa
        'STARTDATE' AS STARTDATE,
        'ENDDATE' AS ENDDATE,
        'DISTUNLOADINGCAPACITY' AS DISTUNLOADINGCAPACITY,
        'UOM' AS UOM,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('unloading_capacity')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('unloading_capacity')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        TRANSMODETYPE::STRING,
        ITEMID::STRING,
        LOCATION::STRING,
        STARTDATE::STRING,
        ENDDATE::STRING,
        DISTUNLOADINGCAPACITY::STRING,
        UOM::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('unloading_capacity') }}
)

SELECT
    TRANSMODETYPE,
    ITEMID,
    LOCATION,
    STARTDATE,
    ENDDATE,
    DISTUNLOADINGCAPACITY,
    UOM,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
