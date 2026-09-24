-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item', 'uomfrom', 'uomto'
] %}
{% set list_another_columns = [
    'supplyplanningfinalconversionfactor'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
UOM_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_uom_conversion_stg') }}
    QUALIFY RN = 1
),

UOM AS (
    SELECT
        S.ITEM,
        S.UOMFROM,
        S.UOMTO,
        S.SUPPLYPLANNINGFINALCONVERSIONFACTOR,
        S.HASH_ID
    FROM UOM_STG AS S
    INNER JOIN {{ ref('item_master') }} AS I
        ON I.ITEM = S.ITEM
)

SELECT *
FROM UOM
