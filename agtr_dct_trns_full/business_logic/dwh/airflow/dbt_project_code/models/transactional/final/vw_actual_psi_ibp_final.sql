-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full', 'delta_onhands'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'ITEM' AS ITEM,
        'RESOURCEID' AS RESOURCEID,
        'LOCATION' AS LOCATION, -- noqa
        'CUSTOMERID' AS CUSTOMERID,
        'DAY' AS DAY, -- noqa
        'VALUETYPE' AS VALUETYPE,
        'VALUEINPUT' AS VALUEINPUT,
        'UOM' AS UOM,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('actual_psi_ibp')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('actual_psi_ibp')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEM::STRING,
        RESOURCEID::STRING,
        LOCATION::STRING,
        CUSTOMERID::STRING,
        DAY::STRING,
        VALUETYPE::STRING,
        VALUEINPUT::STRING,
        UOM::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('actual_psi_ibp') }}
    {% if check_model_group_scheduler(list_tags, 'ActualPsiIbp') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    ITEM,
    RESOURCEID,
    LOCATION,
    CUSTOMERID,
    DAY,
    VALUETYPE,
    VALUEINPUT,
    UOM,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
