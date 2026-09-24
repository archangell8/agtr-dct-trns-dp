-- noqa:disable=RF06
{{
    config(
        materialized='incremental'
    )
}}

-- Only for create the table if not exists
SELECT DISTINCT
    NULL AS "MODEL",
    NULL AS LAST_EXECUTION,
    NULL AS CURRENT_EXECUTION
WHERE 1 = 0
