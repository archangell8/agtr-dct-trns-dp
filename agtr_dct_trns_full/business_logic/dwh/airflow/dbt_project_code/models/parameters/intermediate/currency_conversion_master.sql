-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'currencyfrom', 'currencyto', 'conversionstart', 'conversionend'
] %}
{% set list_another_columns = [
    'conversionfactor'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
CURRENCY_CONVERSION_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_currency_conversion_stg') }}
    QUALIFY RN = 1
),

CURRENCY_CONVERSION AS (
    SELECT
        S.CURRENCYFROM,
        S.CURRENCYTO,
        S.CONVERSIONSTART,
        S.CONVERSIONEND,
        S.CONVERSIONFACTOR,
        S.HASH_ID
    FROM CURRENCY_CONVERSION_STG AS S
)

SELECT *
FROM CURRENCY_CONVERSION
