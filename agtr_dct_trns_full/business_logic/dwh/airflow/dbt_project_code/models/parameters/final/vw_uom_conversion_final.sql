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
        'UOMFROM' AS UOMFROM,
        'UOMTO' AS UOMTO,
        'SUPPLYPLANNINGFINALCONVERSIONFACTOR' AS SUPPLYPLANNINGFINALCONVERSIONFACTOR, -- noqa
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('uom_conversion')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('uom_conversion')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEM::STRING,
        UOMFROM::STRING,
        UOMTO::STRING,
        SUPPLYPLANNINGFINALCONVERSIONFACTOR::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('uom_conversion') }}
    {% if check_model_group_scheduler(list_tags, 'UomConversion') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    ITEM,
    UOMFROM,
    UOMTO,
    SUPPLYPLANNINGFINALCONVERSIONFACTOR,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
