{{
    config(
        materialized='table'
    )
}}

WITH SHIPMENT_STATUS_TEMP AS (

    SELECT
        STATUS,
        REFERENCEDATE,
        SHIPMENTID,
        ITEMID,
        BK,
        COALESCE(QUANTITY::DECIMAL(20, 4), 0) AS QUANTITY,
        UOM
    FROM {{ ref('tab_shipment_status_fbz_stg') }}

    UNION DISTINCT

    SELECT
        STATUS,
        REFERENCEDATE,
        SHIPMENTID,
        ITEMID,
        BK,
        COALESCE(QUANTITY::DECIMAL(20, 4), 0) AS QUANTITY,
        UOM
    FROM {{ ref('tab_shipment_status_fob_stg') }}

    UNION DISTINCT

    SELECT
        STATUS,
        REFERENCEDATE,
        SHIPMENTID,
        ITEMID,
        BK,
        COALESCE(QUANTITY::DECIMAL(20, 4), 0) AS QUANTITY,
        UOM
    FROM {{ ref('tab_shipment_status_cif_stg') }}

    UNION DISTINCT

    SELECT
        STATUS,
        REFERENCEDATE,
        SHIPMENTID,
        ITEMID,
        BK,
        COALESCE(QUANTITY::DECIMAL(20, 4), 0) AS QUANTITY,
        UOM
    FROM {{ ref('tab_shipment_status_transf_stg') }}

    UNION DISTINCT

    SELECT
        STATUS,
        REFERENCEDATE,
        SHIPMENTID,
        ITEMID,
        BK,
        COALESCE(QUANTITY::DECIMAL(20, 4), 0) AS QUANTITY,
        UOM
    FROM {{ ref('tab_shipment_status_venda_stg') }}

),

SHIPMENT_STATUS AS (
    SELECT
        STATUS,
        SHIPMENTID,
        ITEMID,
        BK,
        UOM,
        MAX(REFERENCEDATE) AS REFERENCEDATE,
        SUM(QUANTITY) AS QUANTITY
    FROM SHIPMENT_STATUS_TEMP
    GROUP BY
        STATUS,
        SHIPMENTID,
        ITEMID,
        BK,
        UOM
),

SHIPMENT_STATUS_FINAL AS (
    SELECT -- noqa
        COALESCE(NULLIF(SHIP.STATUS, ''), 'N/A') AS STATUS,
        COALESCE(NULLIF(SHIP.REFERENCEDATE, ''), 'N/A') AS REFERENCEDATE,
        SHIP.SHIPMENTID,
        SHIP.BK,
        SHIP.ITEMID,
        COALESCE(CONV.UOMFROM, 'TN') AS UOM,
        ROUND(
            COALESCE(
                SHIP.QUANTITY / CONV.SUPPLYPLANNINGFINALCONVERSIONFACTOR,
                SHIP.QUANTITY
            ), 3
        ) AS QUANTITY
    FROM SHIPMENT_STATUS AS SHIP
    LEFT JOIN {{ ref('vw_uom_conversion_stg') }} AS CONV
        ON
            TRIM(SHIP.ITEMID) = TRIM(CONV.ITEM)
            AND TRIM(COALESCE(SHIP.UOM, 'KG')) = TRIM(CONV.UOMTO)
            AND TRIM(CONV.UOMFROM) = 'TN'
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SHIPMENT_STATUS_FINAL
WHERE REFERENCEDATE <> 'N/A' AND STATUS <> 'N/A'
