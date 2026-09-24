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
        'ID' AS ID,
        'SHIPMENTID' AS SHIPMENTID,
        'DRIVER' AS DRIVER,
        'PENALTYCOST' AS PENALTYCOST,
        'CURRENCY' AS CURRENCY,
        'REFERENCEDATE' AS REFERENCEDATE,
        'TYPE_OF_COST' AS TYPE_OF_COST,
        'REASON' AS REASON,
        'SUB_REASON' AS SUB_REASON,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('shipment_penalties')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('shipment_penalties')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ID::STRING,
        SHIPMENTID::STRING,
        DRIVER::STRING,
        PENALTYCOST::STRING,
        CURRENCY::STRING,
        REFERENCEDATE::STRING,
        TYPE_OF_COST::STRING,
        REASON::STRING,
        SUB_REASON::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('shipment_penalties') }}
)

SELECT
    ID,
    SHIPMENTID,
    DRIVER,
    PENALTYCOST,
    CURRENCY,
    REFERENCEDATE,
    TYPE_OF_COST,
    REASON,
    SUB_REASON,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
