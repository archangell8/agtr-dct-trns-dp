-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'date', 'item', 'source', 'destination', 'sourcingcontract',
    'carrier', 'type'
] %}
{% set list_another_columns = [
    'transportationnumber', 'volume', 'salesorderdeliveryid', 'finaldestination'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
TRANSPORTATION_SCHEDULE_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_transportation_schedule_stg') }}
    QUALIFY RN = 1
),

TRANSPORTATION_SCHEDULE AS (
    SELECT
        S.DATE,
        I.ITEM,
        S.SOURCE,
        S.DESTINATION,
        S.SOURCINGCONTRACT,
        S.CARRIER,
        S.TYPE,
        S.TRANSPORTATIONNUMBER,
        S.VOLUME,
        S.SALESORDERDELIVERYID,
        S.FINALDESTINATION,
        S.HASH_ID
    FROM TRANSPORTATION_SCHEDULE_STG AS S
    INNER JOIN {{ ref('location_master') }} AS LOC_1
        ON LOC_1.LOCATIONID = S.SOURCE
    INNER JOIN {{ ref('location_master') }} AS LOC_2
        ON LOC_2.LOCATIONID = S.DESTINATION
    INNER JOIN {{ ref('item_master') }} AS I
        ON I.ITEM::INT = S.ITEM::INT
)

SELECT *
FROM TRANSPORTATION_SCHEDULE
