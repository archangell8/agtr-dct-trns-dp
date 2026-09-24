-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'creditor', 'debitor', 'location', 'itemid', 'date'
] %}
{% set list_another_columns = [
    'quantity'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
PORT_SWAP_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_port_swap_stg') }}
    QUALIFY RN = 1
),

PORT_SWAP AS (
    SELECT
        V.CREDITOR,
        V.DEBITOR,
        V.LOCATION,
        V.ITEMID,
        V.DATE,
        V.QUANTITY,
        V.HASH_ID
    FROM PORT_SWAP_STG AS V
    INNER JOIN {{ ref('location_master') }} AS L
        ON V.LOCATION = L.LOCATIONID
    INNER JOIN {{ ref('item_master') }} AS I
        ON V.ITEMID = I.ITEM
)

SELECT *
FROM PORT_SWAP
