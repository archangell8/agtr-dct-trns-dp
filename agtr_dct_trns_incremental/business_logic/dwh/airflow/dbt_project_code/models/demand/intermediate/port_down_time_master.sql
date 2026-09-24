-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'location', 'startdate'
] %}
{% set list_another_columns = [
    'duration'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
PORT_DOWN_TIME_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_port_down_time_stg') }}
    QUALIFY RN = 1
),

PORT_DOWN_TIME AS (
    SELECT
        V.LOCATION,
        V.STARTDATE,
        V.DURATION,
        V.HASH_ID
    FROM PORT_DOWN_TIME_STG AS V
    INNER JOIN {{ ref('location_master') }} AS L
        ON V.LOCATION = L.LOCATIONID
)

SELECT *
FROM PORT_DOWN_TIME
