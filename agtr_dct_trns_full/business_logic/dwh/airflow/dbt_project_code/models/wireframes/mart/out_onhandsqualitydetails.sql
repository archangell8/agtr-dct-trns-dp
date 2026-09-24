-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf_onhandsqualitydetails']
    )
}}

WITH
OH_QUALITY AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        LOCATION,
        ITEM,
        MEASURE AS QUALITY,
        SAMPLE_ID,
        VALUE AS OH_QUALITY_DETAILS,
        TO_CHAR(
            TO_DATE(DAY, 'DD-MM-YYYY HH:MI:SS'),
            'DD-MON-YY'
        ) AS DAY,
        IFF(UNIT = '%', VALUE * 100, VALUE) AS OH_QUALITY_NO_UNIT
    FROM {{ ref('vw_onhands_quality_stg') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM OH_QUALITY
