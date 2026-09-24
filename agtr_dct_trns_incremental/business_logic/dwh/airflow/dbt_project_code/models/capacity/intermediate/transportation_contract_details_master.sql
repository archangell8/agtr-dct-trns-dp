-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'transportationcontractid', 'transportationcontractlineid', 'startdate', 'enddate'
] %}
{% set list_another_columns = [
    'mintolerance', 'source', 'destination', 'itemid',
    'penaltyfee', 'transmode', 'quantity', 'toprate',
    'uom', 'comments', 'paidpenalty', 'currency'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
TRANSPORTATION_CONTACT_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_transportation_contract_details_stg') }}
    QUALIFY RN = 1
),

TRANSPORTATION_CONTACT AS (
    SELECT
        S.TRANSPORTATIONCONTRACTID,
        S.TRANSPORTATIONCONTRACTLINEID,
        S.MINTOLERANCE,
        S.SOURCE,
        S.DESTINATION,
        S.ITEMID,
        S.PENALTYFEE,
        S.TRANSMODE,
        S.STARTDATE,
        S.ENDDATE,
        S.QUANTITY,
        S.TOPRATE,
        S.UOM,
        S.COMMENTS,
        S.PAIDPENALTY,
        S.CURRENCY,
        S.HASH_ID
    FROM TRANSPORTATION_CONTACT_STG AS S
    INNER JOIN (
        SELECT DISTINCT LOCATIONID FROM {{ ref('location_master') }}
        UNION ALL
        SELECT 'N/A' AS LOCATIONID
    ) AS LOC1
        ON LOC1.LOCATIONID = S.SOURCE
    INNER JOIN (-- noqa
        SELECT DISTINCT LOCATION_CODE AS DEST FROM {{ ref('location_master') }}
        UNION ALL
        SELECT DISTINCT LOCATIONID AS DEST FROM {{ ref('location_master') }}
    ) AS LOC2
        ON LOC2.DEST = S.DESTINATION
    INNER JOIN {{ ref('transmode_master') }} AS TRA
        ON TRA.TRANSMODE = S.TRANSMODE
    INNER JOIN (--noqa
        SELECT DISTINCT L1 FROM {{ ref('item_master') }}
    ) AS ITEM
        ON ITEM.L1 = S.ITEMID
)

SELECT *
FROM TRANSPORTATION_CONTACT
