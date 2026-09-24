-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'vesselid', 'date', 'type'
] %}
{% set list_another_columns = [
    'estimatedvalue', 'actualvalue', 'currency', 'itemid'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
PORT_PENALTY_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_port_penalty_stg') }}
    QUALIFY RN = 1
),

PORT_PENALTY AS (
    SELECT
        V.VESSELID,
        V.DATE,
        V.TYPE,
        V.ITEMID,
        V.ESTIMATEDVALUE,
        V.ACTUALVALUE,
        V.CURRENCY,
        V.HASH_ID
    FROM PORT_PENALTY_STG AS V
    INNER JOIN {{ ref('item_master') }} AS I
        ON V.ITEMID = I.ITEM
    INNER JOIN {{ ref('vessel_details_master') }} AS VL
        ON V.VESSELID = VL.ID
)

SELECT *
FROM PORT_PENALTY
