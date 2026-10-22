-- noqa: disable=RF06,RF04
{{
    config(
        materialized='table',
        tags=['wf06']
    )
}}

WITH
SHIPMENTLOADTRACKINGDETAILS AS (
    SELECT
        S.SHIPMENTLINEID,
        S.VEHICALID AS VEHICLE,
        S.SOURCE,
        S.ITEM,
        S.CARRIER,
        S.OPERATIONTYPE,
        S.QUANTITY::DECIMAL(20, 3) AS VOLUME,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN S.DESTINATIONLOCATION
            ELSE 'N/A'
        END AS TRANSSHIPMENT,
        IFF(
            SC.ID IS NOT NULL,
            SC.SUPPLIERID,
            'N/A'
        ) AS SUPPLIERID,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN LD.LOCATION_CODE
            ELSE 'ROD' --#
        END AS TRANSMODE,
        CASE
            WHEN LD.LOCATION_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
                THEN S.FINALDESTINATION
            ELSE S.DESTINATIONLOCATION
        END AS LOCATION,
        IFF(
            SOD.DEMANDID IS NOT NULL,
            SOD.CUSTOMERID,
            'N/A'
        ) AS CUSTOMER
    FROM {{ ref('intstg_shipment_details_without_cancelled_shipments') }} AS S
    INNER JOIN {{ ref('location_master') }} AS LD
        ON S.DESTINATIONLOCATION = LD.LOCATIONID
    INNER JOIN {{ ref('location_master') }} AS LS
        ON S.SOURCE = LS.LOCATIONID
    LEFT JOIN {{ ref('sourcing_contract_details_master') }} AS SC
        ON S.SOURCINGCONTRACTNUMBER = SC.ID
    LEFT JOIN {{ ref('sales_order_delivery_master') }} AS SOD
        ON S.SALESORDERDELIVERYID = SOD.DEMANDID
    WHERE
        1 = 1
        AND LS.LOCATION_UNIT_STRUCTURE IN (
            'PONTO DE COLETA', 'ARMAZÉM', 'FÁBRICA'
        )
)

SELECT *
FROM SHIPMENTLOADTRACKINGDETAILS
