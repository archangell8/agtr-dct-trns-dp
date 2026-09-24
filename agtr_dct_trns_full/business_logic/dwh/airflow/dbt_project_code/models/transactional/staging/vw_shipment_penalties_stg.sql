{{
    config(
        materialized='view'
    )
}}

WITH

SHIPMENT_PENALTIES_STG AS (
    SELECT
        CASE
            WHEN TRIM(CTMS.VEHICLEID) = '' THEN 'N/A'
            ELSE REPLACE(CTMS.VEHICLEID, '-', '')
        END AS VEHICLEID,
        CASE
            WHEN TRIM(CTMS.DRIVER) = '' THEN 'N/A'
            ELSE TRIM(CTMS.DRIVER)
        END AS DRIVER,
        TRIM('BRE') AS CURRENCY,
        TO_CHAR(CTMS.REFERENCEDATE, 'DD-MM-YYYY') AS REFERENCEDATE,
        SPLIT_PART(CTMS.COMMENTS, '//', 1) AS REASON,
        SPLIT_PART(CTMS.COMMENTS, '//', 2) AS SUB_REASON,
        TRIM(CTMS.COMMENTS) AS COMMENTS,
        TRIM(CTMS.LOAD_NUMBER) AS LOAD_NUMBER,
        TRIM(CTMS.COD_DSP) AS COD_FRETE_EXTRA,
        TRIM(CTMS.IND_COMP_FRT) AS IND_COMP_FRT,
        SUM(CTMS.PENALTYCOST) AS PENALTYCOST
    FROM {{ source('ctms', 'VW_DCT_EXTRA') }} AS CTMS
    GROUP BY
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10
),

SHIPMENT_CANCELLED AS (
    SELECT SHIPMENTID AS ID
    FROM {{ ref('tab_shipment_status_stg') }}
    WHERE STATUS = 'CANCELLED'
),

SHIPMENT_DETAILS AS (
    SELECT
        ID,
        BK::STRING AS BK,
        COALESCE(
            NULLIF(LOADNUMBER, 'N/A'), NULLIF(FICHANUMBER, 'N/A'), 'N/A'
        ) AS LOADNUMBER,
        LOADNUMBER AS LOADNUMBER_RAW,
        FICHANUMBER AS FICHANUMBER_RAW
    FROM {{ ref('tab_shipment_details_fob_stg') }}

    UNION ALL

    SELECT
        ID,
        BK::STRING AS BK,
        COALESCE(
            NULLIF(LOADNUMBER, 'N/A'), NULLIF(FICHANUMBER, 'N/A'), 'N/A'
        ) AS LOADNUMBER,
        LOADNUMBER AS LOADNUMBER_RAW,
        FICHANUMBER AS FICHANUMBER_RAW
    FROM {{ ref('tab_shipment_details_fbz_stg') }}

    UNION ALL

    SELECT
        ID,
        BK::STRING AS BK,
        COALESCE(
            NULLIF(LOADNUMBER, 'N/A'), NULLIF(FICHANUMBER, 'N/A'), 'N/A'
        ) AS LOADNUMBER,
        LOADNUMBER AS LOADNUMBER_RAW,
        FICHANUMBER AS FICHANUMBER_RAW
    FROM {{ ref('tab_shipment_details_transf_stg') }}

    UNION ALL

    SELECT
        ID,
        BK::STRING AS BK,
        COALESCE(
            NULLIF(LOADNUMBER, 'N/A'), NULLIF(FICHANUMBER, 'N/A'), 'N/A'
        ) AS LOADNUMBER,
        LOADNUMBER AS LOADNUMBER_RAW,
        FICHANUMBER AS FICHANUMBER_RAW
    FROM {{ ref('tab_shipment_details_cif_stg') }}

    UNION ALL

    SELECT
        ID,
        BK::STRING AS BK,
        COALESCE(
            NULLIF(LOADNUMBER, 'N/A'), NULLIF(FICHANUMBER, 'N/A'), 'N/A'
        ) AS LOADNUMBER,
        LOADNUMBER AS LOADNUMBER_RAW,
        FICHANUMBER AS FICHANUMBER_RAW
    FROM {{ ref('tab_shipment_details_venda_stg') }}
),

SHIPMENT_LOAD AS (
    SELECT
        LOADNUMBER_RAW AS LOADNUMBER,
        COUNT(ID) AS QT_SHIPMENT
    FROM SHIPMENT_DETAILS
    WHERE
        1 = 1
        AND ID NOT IN (
            SELECT S.ID FROM SHIPMENT_CANCELLED AS S
        )
        AND COALESCE(LOADNUMBER_RAW, 'N/A') != 'N/A'
        AND LOADNUMBER_RAW NOT IN (
            SELECT S.FICHANUMBER_RAW
            FROM SHIPMENT_DETAILS AS S
        )
    GROUP BY 1

    UNION -- noqa

    SELECT
        FICHANUMBER_RAW AS FICHANUMBER,
        COUNT(ID) AS QT_SHIPMENT
    FROM SHIPMENT_DETAILS
    WHERE
        1 = 1
        AND ID NOT IN (
            SELECT S.ID FROM SHIPMENT_CANCELLED AS S
        )
        AND COALESCE(FICHANUMBER_RAW, 'N/A') != 'N/A'
    GROUP BY 1
),

SHIPMENT_PENALTIES AS (
    SELECT -- noqa
        CONCAT(
            P.LOAD_NUMBER,
            '-',
            ROW_NUMBER() OVER (
                PARTITION BY P.LOAD_NUMBER
                ORDER BY P.REFERENCEDATE, P.COD_FRETE_EXTRA, S.ID DESC -- noqa
            )
        ) AS ID,
        S.ID AS SHIPMENTID,
        P.VEHICLEID,
        P.DRIVER,
        P.PENALTYCOST,
        Q.QT_SHIPMENT,
        P.CURRENCY,
        P.REFERENCEDATE,
        P.REASON,
        P.SUB_REASON,
        CASE
            WHEN UPPER(P.IND_COMP_FRT) = 'S'
                THEN 'COMPL'
            ELSE
                'EXTRA'
        END AS TYPE_OF_COST
    FROM SHIPMENT_PENALTIES_STG AS P
    INNER JOIN SHIPMENT_DETAILS AS S

        ON P.LOAD_NUMBER = S.LOADNUMBER
    INNER JOIN SHIPMENT_LOAD AS Q
        ON S.LOADNUMBER = Q.LOADNUMBER
    WHERE
        1 = 1
        AND S.ID NOT IN (
            SELECT SC.ID FROM SHIPMENT_CANCELLED AS SC
        )
),

SHIPMENT_PENALTIES_FINAL AS (
    SELECT -- noqa
        ID,
        SHIPMENTID,
        VEHICLEID,
        DRIVER,
        ROUND((PENALTYCOST / QT_SHIPMENT), 3) AS PENALTYCOST,
        CURRENCY,
        REFERENCEDATE,
        TYPE_OF_COST,
        REASON,
        SUB_REASON
    FROM SHIPMENT_PENALTIES
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM SHIPMENT_PENALTIES_FINAL
WHERE
    1 = 1
    AND {{ date_max_filter('REFERENCEDATE', 'DD-MM-YYYY', 'na') }} --noqa
