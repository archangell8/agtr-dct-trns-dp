-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'location', 'resource', 'day', 'classification', 'comments', 'value'
] %}
{% set list_another_columns = [
    'uom', 'type'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
RESOURCE_CAPACITY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_resource_capacity_stg') }}
    QUALIFY RN = 1
),

RESOURCE_CAPACITY AS (
    SELECT
        S.LOCATION,
        S.RESOURCE,
        S.DAY,
        S.CLASSIFICATION,
        S.VALUE,
        S.UOM,
        S.TYPE,
        S.COMMENTS,
        S.HASH_ID
    FROM RESOURCE_CAPACITY_STG AS S
    INNER JOIN {{ ref('location_master') }} AS LOC
        ON S.LOCATION = LOC.LOCATIONID
)

SELECT *
FROM RESOURCE_CAPACITY
