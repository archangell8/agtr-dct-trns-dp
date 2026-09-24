-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'laneid'
] %}
{% set list_another_columns = [
    'location_from', 'location_to', 'transmode', 'lane_description',
    'location_from_unit_structure', 'location_to_unit_structure',
    'islane_optimizable'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
LANE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_lane_stg') }}
    QUALIFY RN = 1
),

LANE AS (
    SELECT
        S.LANEID,
        S.LOCATION_FROM,
        S.LOCATION_TO,
        S.TRANSMODE,
        -- S.MODAL,
        S.LANE_DESCRIPTION,
        S.LOCATION_FROM_UNIT_STRUCTURE,
        S.LOCATION_TO_UNIT_STRUCTURE,
        S.ISLANE_OPTIMIZABLE,
        S.HASH_ID
    FROM LANE_STG AS S
    INNER JOIN {{ ref('location_master') }} AS LOC1
        ON S.LOCATION_FROM = LOC1.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LOC2
        ON S.LOCATION_TO = LOC2.LOCATIONID
    INNER JOIN (
        SELECT DISTINCT LOCATION_UNIT_STRUCTURE FROM {{ ref('location_master') }}
    ) AS LOC3
        ON S.LOCATION_FROM_UNIT_STRUCTURE = LOC3.LOCATION_UNIT_STRUCTURE
    INNER JOIN (
        SELECT DISTINCT LOCATION_UNIT_STRUCTURE FROM {{ ref('location_master') }}
    ) AS LOC4
        ON S.LOCATION_TO_UNIT_STRUCTURE = LOC4.LOCATION_UNIT_STRUCTURE
)

SELECT *
FROM LANE
