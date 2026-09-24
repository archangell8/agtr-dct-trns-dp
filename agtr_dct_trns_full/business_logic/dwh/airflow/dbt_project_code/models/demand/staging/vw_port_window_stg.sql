-- noqa: disable=RF06
{{
    config(
        materialized='view'
    )
}}

WITH VESSEL AS (
    SELECT DISTINCT
        COALESCE(NULLIF(PORTWINDOWID, ''), 'N/A') AS PORTWINDOWID,
        COALESCE(NULLIF(LOCATION, ''), 'N/A') AS "LOCATION",
        NULLIF(
            TO_CHAR(
                TO_DATE(
                    STARTCAK,
                    'DD-MM-YYYY'
                ),
                'DD-MM-YYYY'
            ), ''
        ) AS STARTCAK,
        NULLIF(
            TO_CHAR(
                TO_DATE(
                    ENDCAK,
                    'DD-MM-YYYY'
                ),
                'DD-MM-YYYY'
            ), ''
        ) AS ENDCAK,
        NULLIF(
            TO_CHAR(
                TO_DATE(
                    STARTROLLING,
                    'DD-MM-YYYY'
                ),
                'DD-MM-YYYY'
            ), ''
        ) AS STARTROLLING,
        NULLIF(
            TO_CHAR(
                TO_DATE(
                    ENDROLLING,
                    'DD-MM-YYYY'
                ),
                'DD-MM-YYYY'
            ), ''
        ) AS ENDROLLING,
        COALESCE(NULLIF(PORTWINDOWSTATUS, ''), 'N/A') AS PORTWINDOWSTATUS,
        COALESCE(
            REPLACE(QUANTITY, ',', '.')::DECIMAL(20, 4),
            0
        ) AS QUANTITY,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM
    FROM {{ source('pscfl', 'F_MIN_PORTWINDOW') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM VESSEL
WHERE
    1 = 1
    AND TRY_TO_DATE(STARTCAK, 'DD-MM-YYYY') >= '2025-01-01'::DATE
    AND {{ date_max_filter('STARTCAK', 'DD-MM-YYYY', 'null') }} --noqa
    AND {{ date_max_filter('ENDCAK', 'DD-MM-YYYY', 'null') }} --noqa
    AND {{ date_max_filter('STARTROLLING', 'DD-MM-YYYY', 'null') }} --noqa
    AND {{ date_max_filter('ENDROLLING', 'DD-MM-YYYY', 'null') }} --noqa
