{{
    config(
        materialized='incremental',
        tags=['wf38a']
    )
}}

SELECT
    NULL AS CONTRACT_LINEID,
    NULL AS SOURCE,
    NULL AS CREATION_DATE
WHERE 1 = 0
-- This model was created only to create the empty table if it does not exists.
