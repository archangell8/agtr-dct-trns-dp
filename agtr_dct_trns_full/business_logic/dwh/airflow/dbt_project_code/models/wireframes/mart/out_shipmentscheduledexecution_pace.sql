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
        TRANSSHIPMENT,
        LOCATION,
        OPERATIONTYPE,
        SUPPLIERID,
        SOURCE,
        TRANSMODE,
        CARRIER,
        CUSTOMER,
        PLANNED::INT AS PLANNED,
        OC_DELAYED::INT AS OC_DELAYED,
        OC_EMIT::INT AS OC_EMIT,
        LOADING_ORDER::INT AS LOADING_ORDER,
        CHECKIN::INT AS CHECKIN,
        INVOICE::INT AS INVOICE,
        TO_CHAR(DAY, 'DD-MON-YY') AS DAY
    FROM {{ ref('intstg_shipmentscheduledexecution_pace') }}
    WHERE
        1 = 1
        AND DAY IS NOT NULL
)

SELECT
    VERSION_NAME,
    ITEM,
    TRANSSHIPMENT,
    LOCATION,
    OPERATIONTYPE,
    SUPPLIERID,
    SOURCE,
    TRANSMODE,
    CARRIER,
    CUSTOMER,
    DAY,
    PLANNED,
    OC_DELAYED,
    OC_EMIT,
    LOADING_ORDER,
    CHECKIN,
    INVOICE,
    HASH(*) AS HASH_ID
FROM FINAL
