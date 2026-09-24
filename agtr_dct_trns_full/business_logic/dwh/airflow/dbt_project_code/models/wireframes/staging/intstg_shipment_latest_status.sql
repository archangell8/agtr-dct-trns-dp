-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['wf16']
    )
}}

WITH
STATUSQUALITY AS (
    SELECT
        SHIPMENTLINEID,
        MAX(STATUSORDER) AS MAXSTATUS
    FROM {{ ref('intstg_shipment_status_quality_details') }}
    GROUP BY SHIPMENTLINEID
)

SELECT DISTINCT
    A.ID,
    C.SOURCINGCONTRACTNUMBER,
    B.SHIPMENTLINEID,
    A.STATUS AS LATESTSTATUS,
    A.STATUSQUANTITY::DECIMAL(20, 3) AS STATUSQUANTITY,
    TO_DATE(A.STATUSDATE, 'DD-MM-YYYY') AS LATESTSTATUSDATE
FROM {{ ref('intstg_shipment_status_quality_details') }} AS A
INNER JOIN STATUSQUALITY AS B
    ON
        A.SHIPMENTLINEID = B.SHIPMENTLINEID
        AND A.STATUSORDER = B.MAXSTATUS
INNER JOIN {{ ref('intstg_shipment_details') }} AS C
    ON A.ID = C.ID
