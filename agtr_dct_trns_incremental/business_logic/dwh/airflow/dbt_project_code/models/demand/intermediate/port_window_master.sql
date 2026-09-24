-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'portwindowid'
] %}
{% set list_another_columns = [
    'location', 'startcak', 'endcak', 'startrolling', 'endrolling',
    'portwindowstatus', 'quantity', 'uom'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
PORT_WINDOW_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_port_window_stg') }}
    QUALIFY RN = 1
),

PORT_WINDOW AS (
    SELECT
        V.PORTWINDOWID,
        V.LOCATION,
        V.STARTCAK,
        V.ENDCAK,
        V.STARTROLLING,
        V.ENDROLLING,
        V.PORTWINDOWSTATUS,
        V.QUANTITY,
        V.UOM,
        V.HASH_ID
    FROM PORT_WINDOW_STG AS V
    INNER JOIN (
        SELECT DISTINCT LOCATIONID FROM {{ ref('location_master') }}
    ) AS L
        ON V.LOCATION = L.LOCATIONID
)

SELECT *
FROM PORT_WINDOW
