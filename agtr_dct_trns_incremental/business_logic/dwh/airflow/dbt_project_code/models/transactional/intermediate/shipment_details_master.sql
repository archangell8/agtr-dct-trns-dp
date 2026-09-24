-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'itemid'
] %}
{% set list_another_columns = [
    'operationtype', 'source', 'sourcebp', 'destination', 'loadnumber',
    'laneid', 'sourcingcontractid', 'transmode', 'carrier', 'vehicleid',
    'estimatedshipdate', 'actualshipdate', 'scheduleddate', 'arrivaldate',
    'estimateddeliverydate', 'actualdeliverydate', 'loadapplicationdate',
    'salesorderdeliveryid', 'finaldestination', 'pricetype', 'plannedcost',
    'actualcost', 'penaltycost', 'quantity', 'uom', 'currency', 'bk',
    'contract_number_applied', 'palletquantity', 'pallet', 'profile',
    'quality_adjustment', 'numero_oc', 'tn', 'rota', 'data_prev_coleta',
    'data_emissao_oc', 'data_validacao_qrcode', 'data_emissao_nf_load',
    'data_emissao_nf_ficha'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
SHIPMENT_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_shipment_details_stg') }}
    WHERE
        1 = 1
    QUALIFY RN = 1
),

SHIPMENT AS (
    SELECT
        SHIP_STG.ID,
        SHIP_STG.OPERATIONTYPE,
        SHIP_STG.SOURCE,
        SHIP_STG.SOURCEBP,
        SHIP_STG.DESTINATION,
        SHIP_STG.LOADNUMBER,
        SHIP_STG.LANEID,
        SHIP_STG.SOURCINGCONTRACTID,
        SHIP_STG.TRANSMODE,
        SHIP_STG.CARRIER,
        SHIP_STG.VEHICLEID,
        SHIP_STG.ESTIMATEDSHIPDATE,
        SHIP_STG.ACTUALSHIPDATE,
        SHIP_STG.SCHEDULEDDATE,
        SHIP_STG.ARRIVALDATE,
        SHIP_STG.ESTIMATEDDELIVERYDATE,
        SHIP_STG.ACTUALDELIVERYDATE,
        SHIP_STG.LOADAPPLICATIONDATE,
        SHIP_STG.SALESORDERDELIVERYID,
        SHIP_STG.FINALDESTINATION,
        SHIP_STG.PALLET,
        SHIP_STG.PALLETQUANTITY,
        SHIP_STG.PROFILE,
        SHIP_STG.PRICETYPE,
        SHIP_STG.ITEMID,
        SHIP_STG.PLANNEDCOST,
        SHIP_STG.ACTUALCOST,
        SHIP_STG.PENALTYCOST,
        SHIP_STG.QUANTITY,
        SHIP_STG.UOM,
        SHIP_STG.CURRENCY,
        SHIP_STG.BK,
        SHIP_STG.CONTRACT_NUMBER_APPLIED,
        SHIP_STG.QUALITY_ADJUSTMENT,
        SHIP_STG.NUMERO_OC,
        SHIP_STG.TN,
        SHIP_STG.ROTA,
        SHIP_STG.DATA_PREV_COLETA,
        SHIP_STG.DATA_EMISSAO_OC,
        SHIP_STG.DATA_VALIDACAO_QRCODE,
        SHIP_STG.DATA_EMISSAO_NF_LOAD,
        SHIP_STG.DATA_EMISSAO_NF_FICHA,
        SHIP_STG.HASH_ID
    FROM SHIPMENT_STG AS SHIP_STG
    INNER JOIN {{ ref('location_master') }} AS LOC1
        ON SHIP_STG.SOURCE = LOC1.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LOC2
        ON SHIP_STG.SOURCEBP = LOC2.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LOC3
        ON SHIP_STG.DESTINATION = LOC3.LOCATIONID
    LEFT JOIN {{ ref('lane_master') }} AS L
        ON L.LANEID = SHIP_STG.LANEID
    INNER JOIN ( --noqa
        SELECT DISTINCT ID FROM {{ ref('sourcing_contract_details_master') }}
        UNION
        SELECT 'N/A' AS ID
    ) AS SC
        ON SHIP_STG.SOURCINGCONTRACTID = SC.ID
    LEFT JOIN {{ ref('itemlanetransmode_master') }} AS B
        ON L.LANEID = B.BODLANEID
    INNER JOIN {{ ref('item_master') }} AS I
        ON SHIP_STG.ITEMID = I.ITEM
)

SELECT *
FROM SHIPMENT
