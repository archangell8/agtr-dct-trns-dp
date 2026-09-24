-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
ONHANDS_QUALITY AS (
    SELECT DISTINCT
        MEASURE AS QUALITY,
        UNIT,
        CONCAT(MEASURE, ' (', UNIT, ')') AS QUALITY_DISPLAYNAME
    FROM {{ ref('vw_onhands_quality_stg') }}
),

SHIPMENT_QUALITY AS (
    SELECT DISTINCT
        MEASURE AS QUALITY,
        UNIT,
        CONCAT(MEASURE, ' (', UNIT, ')') AS QUALITY_DISPLAYNAME
    FROM {{ ref('shipment_status_quality_details_master') }}
),

QUALITY_MASTER AS (
    SELECT
        QUALITY,
        QUALITY_DISPLAYNAME,
        UNIT
    FROM ONHANDS_QUALITY

    UNION DISTINCT

    SELECT
        QUALITY,
        QUALITY_DISPLAYNAME,
        UNIT
    FROM SHIPMENT_QUALITY
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM QUALITY_MASTER
