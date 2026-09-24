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
        'ITEMID' AS ITEMID,
        'SOURCEID' AS SOURCEID,
        'TRANSMODE' AS TRANSMODE,
        'FINALDESTINATIONID' AS FINALDESTINATIONID,
        'DAY' AS DAY, -- noqa
        'PLANNEDQUANTITY' AS PLANNEDQUANTITY,
        'UOM' AS UOM,
        'OPERATOR' AS OPERATOR,
        'OPERATIONTYPE' AS OPERATIONTYPE,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('distribution_operational')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('distribution_operational')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEMID::STRING,
        SOURCEID::STRING,
        TRANSMODE::STRING,
        FINALDESTINATIONID::STRING,
        DAY::STRING,
        PLANNEDQUANTITY::STRING,
        UOM::STRING,
        OPERATOR::STRING,
        OPERATIONTYPE::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('distribution_operational') }}
    {% if check_model_group_scheduler(list_tags, 'DistributionOperational') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    ITEMID,
    SOURCEID,
    TRANSMODE,
    FINALDESTINATIONID,
    DAY,
    PLANNEDQUANTITY,
    UOM,
    OPERATOR,
    OPERATIONTYPE,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
