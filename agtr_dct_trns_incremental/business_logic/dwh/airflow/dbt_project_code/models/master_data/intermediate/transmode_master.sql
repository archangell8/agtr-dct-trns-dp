-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'transmode'
] %}
{% set list_another_columns = [
    'transmodedescription', 'transmodetype'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
TRANSMODE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_transmode_stg') }}
    QUALIFY RN = 1
),

TRANSMODE AS (
    SELECT
        S.TRANSMODE,
        S.TRANSMODEDESCRIPTION,
        S.TRANSMODETYPE,
        S.HASH_ID
    FROM TRANSMODE_STG AS S
)

SELECT *
FROM TRANSMODE
