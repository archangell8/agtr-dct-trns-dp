-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full', 'delta_vessel'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'QUANTITY' AS QUANTITY,
        'CREDITOR' AS CREDITOR,
        'DEBITOR' AS DEBITOR,
        'LOCATION' AS LOCATION, -- noqa
        'ITEMID' AS ITEMID,
        'DATE' AS DATE, -- noqa
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('port_swap')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('port_swap')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        QUANTITY::STRING,
        CREDITOR::STRING,
        DEBITOR::STRING,
        LOCATION::STRING,
        ITEMID::STRING,
        DATE::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('port_swap') }}
)

SELECT
    QUANTITY,
    CREDITOR,
    DEBITOR,
    LOCATION,
    ITEMID,
    DATE,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
