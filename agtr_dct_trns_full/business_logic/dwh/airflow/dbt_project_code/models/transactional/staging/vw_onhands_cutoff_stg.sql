-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH
CUTOFF AS (
    SELECT
        LOC.LOCATION_UNIT_ID AS "LOCATION",
        0 AS BLOCKEDQUANTITY,
        0 AS ONHANDQUANTITY,
        0 AS QUARANTINEQUANTITY,
        'TN' AS UOM,
        TRIM(CUT.ILLITM) AS ITEM,
        TO_CHAR({{ julian_date_to_gregorian('CUT', 'ILDGL') }}, 'DD-MM-YYYY HH24:mi:SS') AS "DAY", --noqa
        CASE
            WHEN TRIM(CUT.ILKCO) = '52180' THEN 'CNH'
            WHEN TRIM(CUT.ILKCO) = '52191' THEN 'AMIDOS'
            ELSE 'CARGILL'
        END AS COMPANY,
        SUM(CUT.ILTRQT) / 1000 AS CUTOFFQUANTITY
    FROM {{ source('jde', 'F4111') }} AS CUT
    INNER JOIN {{ ref('tab_location_internal_stg') }} AS LOC
        ON TRIM(CUT.ILMCU) = TRIM(LOC.LOCATIONID)
    INNER JOIN {{ ref('item_master') }} AS IT
        ON TRIM(CUT.ILLITM) = TRIM(IT.ITEM)
    WHERE
        1 = 1
        AND CUT.ILDCT IN ('PI', 'I3', 'IS', 'IF', 'IO')
        AND LOC.LOCATION_UNIT_STRUCTURE = 'FÁBRICA'
        AND {{ filter_remove_jde_delete_data('CUT') }} --noqa
        AND MONTH({{ julian_date_to_gregorian('CUT', 'ILDGL') }}) = MONTH(CURRENT_DATE()) --noqa
        AND YEAR({{ julian_date_to_gregorian('CUT', 'ILDGL') }}) = YEAR(CURRENT_DATE()) --noqa
    GROUP BY
        TRIM(CUT.ILLITM),
        LOC.LOCATION_UNIT_ID,
        CUT.ILDGL,
        UOM,
        TRIM(CUT.ILKCO)
)

SELECT
    ITEM,
    LOCATION,
    DAY,
    BLOCKEDQUANTITY,
    ONHANDQUANTITY,
    QUARANTINEQUANTITY,
    CUTOFFQUANTITY,
    UOM,
    COMPANY
FROM CUTOFF
