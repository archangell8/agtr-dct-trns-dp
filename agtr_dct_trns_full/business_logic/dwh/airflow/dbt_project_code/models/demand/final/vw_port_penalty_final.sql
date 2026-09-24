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
        'VESSELID' AS VESSELID,
        'DATE' AS DATE, -- noqa
        'ITEMID' AS ITEMID,
        'TYPE' AS TYPE, -- noqa
        'ESTIMATEDVALUE' AS ESTIMATEDVALUE,
        'ACTUALVALUE' AS ACTUALVALUE,
        'CURRENCY' AS CURRENCY,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('port_penalty')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('port_penalty')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        VESSELID::STRING,
        DATE::STRING,
        ITEMID::STRING,
        TYPE::STRING,
        ESTIMATEDVALUE::STRING,
        ACTUALVALUE::STRING,
        CURRENCY::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('port_penalty') }}
    {% if check_model_group_scheduler(list_tags, 'PortPenalty') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    VESSELID,
    DATE,
    ITEMID,
    TYPE,
    ESTIMATEDVALUE,
    ACTUALVALUE,
    CURRENCY,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
