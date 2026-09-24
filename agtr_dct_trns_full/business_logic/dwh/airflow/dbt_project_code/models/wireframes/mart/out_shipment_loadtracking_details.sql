-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf06']
    )
}}

WITH
FINAL AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        SHIPMENTLINEID AS SHIPMENT_LINEID,
        VEHICLE,
        TRANSSHIPMENT,
        SOURCE,
        SUPPLIERID,
        ITEM,
        TRANSMODE,
        "LOCATION",
        CARRIER,
        CUSTOMER,
        OPERATIONTYPE AS OPERATION_TYPE,
        VOLUME
    FROM {{ ref('intstg_shipment_loadtracking_details') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM FINAL
