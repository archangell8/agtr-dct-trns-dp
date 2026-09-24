-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
SAMPLEID_MASTER AS (
    SELECT DISTINCT SAMPLE_ID
    FROM {{ ref('vw_onhands_quality_stg') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SAMPLEID_MASTER
