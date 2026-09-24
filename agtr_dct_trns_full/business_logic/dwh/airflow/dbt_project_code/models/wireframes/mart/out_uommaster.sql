-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
UOM_MASTER AS (
    SELECT DISTINCT UOMTO AS UOM
    FROM {{ ref('uom_conversion_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM UOM_MASTER
