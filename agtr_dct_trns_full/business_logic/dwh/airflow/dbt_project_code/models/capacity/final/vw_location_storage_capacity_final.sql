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
        'MINCAPACITY' AS MINCAPACITY,
        'MAXCAPACITY' AS MAXCAPACITY,
        'UOM' AS UOM,
        'LOCATIONID' AS LOCATIONID,
        'MONTH' AS MONTH, -- noqa
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('location_storage_capacity')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('location_storage_capacity')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEMID::STRING,
        MINCAPACITY::STRING,
        MAXCAPACITY::STRING,
        UOM::STRING,
        LOCATIONID::STRING,
        MONTH::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('location_storage_capacity') }}
)

SELECT
    ITEMID,
    MINCAPACITY,
    MAXCAPACITY,
    UOM,
    LOCATIONID,
    MONTH,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
