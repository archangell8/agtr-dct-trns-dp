-- noqa:disable=RF06

{{
    config(
        materialized='incremental'
    )
}}

-- Only for create the table if not exists (reserved to API)
SELECT DISTINCT
    NULL AS APPLICATION_NAME,
    NULL AS REFERENCE_TIMESTAMP,
    NULL AS JSON_CONTENT
WHERE 1 = 0
