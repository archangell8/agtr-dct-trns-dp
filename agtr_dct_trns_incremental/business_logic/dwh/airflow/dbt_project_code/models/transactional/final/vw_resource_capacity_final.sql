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
        'LOCATION' AS "LOCATION",
        'RESOURCE' AS "RESOURCE",
        'DAY' AS "DAY",
        'CLASSIFICATION' AS "CLASSIFICATION",
        'VALUE' AS "VALUE",
        'UOM' AS "UOM",
        'TYPE' AS "TYPE",
        'COMMENTS' AS "COMMENTS",
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('resource_capacity')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('resource_capacity')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        LOCATION::STRING,
        "RESOURCE"::STRING,
        DAY::STRING,
        CLASSIFICATION::STRING,
        VALUE::STRING,
        UOM::STRING,
        TYPE::STRING,
        COMMENTS::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('resource_capacity') }}
)

SELECT
    LOCATION,
    RESOURCE,
    DAY,
    CLASSIFICATION,
    VALUE,
    UOM,
    TYPE,
    COMMENTS,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
