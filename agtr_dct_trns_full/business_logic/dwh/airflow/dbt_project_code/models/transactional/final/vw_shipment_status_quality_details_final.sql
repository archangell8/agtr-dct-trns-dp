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
        'SHIPMENTID' AS SHIPMENTID,
        'STATUS' AS STATUS,
        'STATUSREFERENCEDATE' AS STATUSREFERENCEDATE,
        'QUANTITY' AS QUANTITY,
        'STATUSQUALITYREFERENCEDATE' AS STATUSQUALITYREFERENCEDATE,
        'MEASURE' AS MEASURE,
        'VALUE' AS VALUE, -- noqa
        'UNIT' AS UNIT,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('shipment_status_quality_details')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('shipment_status_quality_details')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        SHIPMENTID::STRING,
        STATUS::STRING,
        STATUSREFERENCEDATE::STRING,
        QUANTITY::STRING,
        STATUSQUALITYREFERENCEDATE::STRING,
        MEASURE::STRING,
        VALUE::STRING,
        UNIT::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('shipment_status_quality_details') }}
)

SELECT
    SHIPMENTID,
    STATUS,
    STATUSREFERENCEDATE,
    QUANTITY,
    STATUSQUALITYREFERENCEDATE,
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
