-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
LANE_MASTER AS (
    SELECT DISTINCT
        A.LANEID AS BODLANE,
        A.LANE_DESCRIPTION,
        A.LOCATION_FROM AS FROM_LOCATION,
        A.LOCATION_TO AS TO_LOCATION,
        A.LOCATION_TO AS DESTINATION,
        A.LOCATION_FROM AS ORIGIN,
        B.LOCATION_SUB_REGION AS ORIGIN_SUB_REGION,
        A.ISLANE_OPTIMIZABLE AS OPTIMIZABLE
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('location_master') }} AS B
        ON A.LOCATION_FROM = B.LOCATIONID
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM LANE_MASTER
