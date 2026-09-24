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
        'ITEM' AS ITEM,
        'RESOURCEID' AS RESOURCEID,
        'LOCATION' AS LOCATION, -- noqa
        'CUSTOMERID' AS CUSTOMERID,
        'MONTH' AS MONTH, -- noqa
        'VALUETYPE' AS VALUETYPE,
        'VALUEINPUT' AS VALUEINPUT,
        'UOM' AS UOM,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('psi_ibp')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('psi_ibp')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEM::STRING,
        RESOURCEID::STRING,
        LOCATION::STRING,
        CUSTOMERID::STRING,
        MONTH::STRING,
        VALUETYPE::STRING,
        VALUEINPUT::STRING,
        UOM::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('psi_ibp') }}
)

SELECT
    ITEM,
    RESOURCEID,
    LOCATION,
    CUSTOMERID,
    MONTH,
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
