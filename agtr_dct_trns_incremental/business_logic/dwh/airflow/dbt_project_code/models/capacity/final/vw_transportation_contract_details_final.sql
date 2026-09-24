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
        'TRANSPORTATIONCONTRACTID' AS TRANSPORTATIONCONTRACTID,
        'TRANSPORTATIONCONTRACTLINEID' AS TRANSPORTATIONCONTRACTLINEID,
        'MINTOLERANCE' AS MINTOLERANCE,
        'SOURCE' AS SOURCE,
        'DESTINATION' AS DESTINATION,
        'ITEMID' AS ITEMID,
        'PENALTYFEE' AS PENALTYFEE,
        'TRANSMODE' AS TRANSMODE,
        'STARTDATE' AS STARTDATE,
        'ENDDATE' AS ENDDATE,
        'QUANTITY' AS QUANTITY,
        'TOPRATE' AS TOPRATE,
        'UOM' AS UOM,
        'COMMENTS' AS COMMENTS,
        'PAIDPENALTY' AS PAIDPENALTY,
        'CURRENCY' AS CURRENCY,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('transportation_contract_details')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('transportation_contract_details')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        TRANSPORTATIONCONTRACTID::STRING,
        TRANSPORTATIONCONTRACTLINEID::STRING,
        MINTOLERANCE::STRING,
        SOURCE::STRING,
        DESTINATION::STRING,
        ITEMID::STRING,
        PENALTYFEE::STRING,
        TRANSMODE::STRING,
        STARTDATE::STRING,
        ENDDATE::STRING,
        QUANTITY::STRING,
        TOPRATE::STRING,
        UOM::STRING,
        COMMENTS::STRING,
        PAIDPENALTY::STRING,
        CURRENCY::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('transportation_contract_details') }}
    {% if check_model_group_scheduler(list_tags, 'TransportationContractDetails') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    TRANSPORTATIONCONTRACTID,
    TRANSPORTATIONCONTRACTLINEID,
    MINTOLERANCE,
    SOURCE,
    DESTINATION,
    ITEMID,
    PENALTYFEE,
    TRANSMODE,
    STARTDATE,
    ENDDATE,
    QUANTITY,
    TOPRATE,
    UOM,
    COMMENTS,
    PAIDPENALTY,
    CURRENCY,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
