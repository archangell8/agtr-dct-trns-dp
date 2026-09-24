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
        ITEM,
        SOURCE,
        DESTINATION AS "LOCATION",
        TRANSMODE,
        TYPE AS OPERATION_TYPE,
        STATUS,
        CARRIER,
        SUM(SHIPMENTQTY)::DECIMAL(20, 3) AS SHIPMENT_QTY_INTERMEDIATE_WF06B,
        SUM(NUMBER_OF_SHIPMENTS)::INT AS NUMBER_OF_SHIPMENTS_INTERMEDIATE_WF06B,
        TO_CHAR(DAY, 'DD-MON-YY') AS DAY,
        MAX(PACE) AS PACE_INTERMEDIATE_WF06B
    FROM {{ ref('intstg_shipment_status_tracking_pace') }}
    WHERE
        1 = 1
        AND DAY IS NOT NULL
    GROUP BY
        ITEM,
        SOURCE,
        DESTINATION,
        TRANSMODE,
        TYPE,
        STATUS,
        CARRIER,
        DAY
)

SELECT
    VERSION_NAME,
    ITEM,
    SOURCE,
    LOCATION,
    TRANSMODE,
    OPERATION_TYPE,
    STATUS,
    CARRIER,
    DAY,
    SHIPMENT_QTY_INTERMEDIATE_WF06B,
    PACE_INTERMEDIATE_WF06B,
    NUMBER_OF_SHIPMENTS_INTERMEDIATE_WF06B,
    HASH(*) AS HASH_ID
FROM FINAL
