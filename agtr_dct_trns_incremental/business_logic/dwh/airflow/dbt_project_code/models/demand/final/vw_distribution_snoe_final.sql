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
        'REFERENCEDATE' AS REFERENCEDATE,
        'ITEMID' AS ITEMID,
        'SOURCEID' AS SOURCEID,
        'TRANSMODE' AS TRANSMODE,
        'FINALDESTINATIONID' AS FINALDESTINATIONID,
        'DAY' AS DAY,
        'PLANNEDQUANTITY' AS PLANNEDQUANTITY,
        'UOM' AS UOM,
        'OPERATOR' AS OPERATOR,
        'OPERATIONTYPE' AS OPERATIONTYPE,
        'ISBASELINE' AS ISBASELINE,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('distribution_snoe')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('distribution_snoe')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        REFERENCEDATE::STRING,
        ITEMID::STRING,
        SOURCEID::STRING,
        TRANSMODE::STRING,
        FINALDESTINATIONID::STRING,
        DAY::STRING,
        PLANNEDQUANTITY::STRING,
        UOM::STRING,
        OPERATOR::STRING,
        OPERATIONTYPE::STRING,
        ISBASELINE::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('distribution_snoe') }}
    {% if check_model_group_scheduler(list_tags, 'DistributionSnoe') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    REFERENCEDATE,
    ITEMID,
    SOURCEID,
    TRANSMODE,
    FINALDESTINATIONID,
    DAY,
    PLANNEDQUANTITY,
    UOM,
    OPERATOR,
    OPERATIONTYPE,
    ISBASELINE,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
