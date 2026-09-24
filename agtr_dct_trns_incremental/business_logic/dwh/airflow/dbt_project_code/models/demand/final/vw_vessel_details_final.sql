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
        'ID' AS ID,
        'NAME' AS NAME, -- noqa
        'ESTIMATEDTIMEARRIVAL' AS ESTIMATEDTIMEARRIVAL,
        'ESTIMATEDTIMEBERTHING' AS ESTIMATEDTIMEBERTHING,
        'ESTIMATEDTIMECOMPLETION' AS ESTIMATEDTIMECOMPLETION,
        'LAYCANMIN' AS LAYCANMIN,
        'LAYCANMAX' AS LAYCANMAX,
        'CHARTER' AS CHARTER,
        'LOCATION' AS LOCATION, -- noqa
        'DEMURRAGERATE' AS DEMURRAGERATE,
        'DESPATCHRATE' AS DESPATCHRATE,
        'BUYER' AS BUYER,
        'DESTINATION' AS DESTINATION,
        'ITEMID' AS ITEMID,
        'PLANNEDQUANTITY' AS PLANNEDQUANTITY,
        'UOM' AS UOM,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('vessel_details')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('vessel_details')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ID::STRING,
        NAME::STRING,
        ESTIMATEDTIMEARRIVAL::STRING,
        ESTIMATEDTIMEBERTHING::STRING,
        ESTIMATEDTIMECOMPLETION::STRING,
        LAYCANMIN::STRING,
        LAYCANMAX::STRING,
        CHARTER::STRING,
        LOCATION::STRING,
        DEMURRAGERATE::STRING,
        DESPATCHRATE::STRING,
        BUYER::STRING,
        DESTINATION::STRING,
        ITEMID::STRING,
        PLANNEDQUANTITY::STRING,
        UOM::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('vessel_details') }}
    {% if check_model_group_scheduler(list_tags, 'VesselDetails') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    ID,
    NAME,
    ESTIMATEDTIMEARRIVAL,
    ESTIMATEDTIMEBERTHING,
    ESTIMATEDTIMECOMPLETION,
    LAYCANMIN,
    LAYCANMAX,
    CHARTER,
    LOCATION,
    DEMURRAGERATE,
    DESPATCHRATE,
    BUYER,
    DESTINATION,
    ITEMID,
    PLANNEDQUANTITY,
    UOM,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
