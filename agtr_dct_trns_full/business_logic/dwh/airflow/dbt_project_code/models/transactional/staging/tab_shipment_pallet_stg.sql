-- noqa: disable=ST09
{{
    config(
        materialized='table'
    )
}}

WITH SHIP_PALLET AS (

    SELECT
        F55.QXLDNM AS LOAD_NUMBER,
        LISTAGG(DISTINCT UDC.PALLET, ',') AS PALLET,
        SUM(F42.SDUORG::BIGINT / 1000) AS PALLETQUANTITY
    FROM {{ source('jde', 'F4211') }} AS F42
    INNER JOIN (  -- noqa
        SELECT
            SOURCE_CODE AS PRODUCT_CODE,
            TARGET_CODE AS PALLET
        FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
        WHERE
            CATEGORY = 'SHIPMENT'
            AND STAGE = 'PALLET'
    ) AS UDC
        ON TRIM(F42.SDLITM) = TRIM(UDC.PRODUCT_CODE)
    INNER JOIN {{ source('jde', 'F5549015') }} AS F55
        ON
            F55.QXKCOO = F42.SDKCOO
            AND F55.QXDOCO = F42.SDDOCO
            AND F55.QXDCTO = F42.SDDCTO
            AND F55.QXSLNE = F42.SDLNID
    WHERE
        1 = 1
        AND {{ filter_remove_jde_delete_data('F42') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F55') }} -- noqa
        AND F42.SDKCOO IN ('52171', '52180')
    GROUP BY 1
)

SELECT *
FROM SHIP_PALLET
