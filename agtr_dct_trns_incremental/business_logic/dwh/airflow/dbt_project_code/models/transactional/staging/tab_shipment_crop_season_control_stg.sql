-- noqa: disable=all
{{
    config(
        materialized='table'
    )
}}

WITH

MASS_BALANCE AS (
    SELECT *, 'FIRST' AS STEP -- noqa
    FROM {{ ref('tab_shipment_mass_balance_first_leg_stg') }}
    UNION
    SELECT *, 'ONLY_SECOND' AS STEP  -- noqa
    FROM {{ ref('tab_shipment_mass_balance_sec_leg_stg') }}
    WHERE
        CROP_BUSINESS_KEY NOT IN
        (
            SELECT CROP_BUSINESS_KEY
            FROM {{ ref('tab_shipment_mass_balance_first_leg_stg') }}
        )
),

CHECK_CROP_SEASON AS (
    SELECT -- noqa
        CP_CURRENT.CROP_BUSINESS_KEY,
        CP_CURRENT.INVOICE_ISSUANCE_DATE AS CURR_CROP_DATE,
        CP_NEXT.INVOICE_ISSUANCE_DATE AS NEXT_CROP_DATE,
        CP_BEFORE.INVOICE_ISSUANCE_DATE AS BEF_CROP_DATE,
        CP_CURRENT.RK,
        CASE
            WHEN DATEDIFF(DAY, CP_CURRENT.INVOICE_ISSUANCE_DATE ,CP_BEFORE.INVOICE_ISSUANCE_DATE) <= -90  -- noqa
                OR CP_BEFORE.INVOICE_ISSUANCE_DATE IS NULL
                    THEN CP_CURRENT.RK
        END AS CROP_SEASON_BEGIN,
        CASE
            WHEN DATEDIFF(DAY, CP_CURRENT.INVOICE_ISSUANCE_DATE ,CP_NEXT.INVOICE_ISSUANCE_DATE) >= 90  -- noqa
                OR CP_NEXT.INVOICE_ISSUANCE_DATE IS NULL
                    THEN CP_CURRENT.RK
        END AS CROP_SEASON_END,
        CP_CURRENT.STEP
    FROM MASS_BALANCE AS CP_CURRENT
    LEFT JOIN MASS_BALANCE AS CP_NEXT
        ON
            CP_CURRENT.CROP_BUSINESS_KEY = CP_NEXT.CROP_BUSINESS_KEY
            AND CP_CURRENT.RK + 1 = CP_NEXT.RK
    LEFT JOIN MASS_BALANCE AS CP_BEFORE
        ON
            CP_CURRENT.CROP_BUSINESS_KEY = CP_BEFORE.CROP_BUSINESS_KEY
            AND CP_CURRENT.RK = CP_BEFORE.RK + 1
    --ORDER BY 1, 2 -- noqa
),

CROP_BEG_END AS (
    SELECT DISTINCT -- noqa
        CROP_BUSINESS_KEY,
        CROP_SEASON_BEGIN,
        CROP_SEASON_END,
        STEP,
        RANK() OVER (PARTITION BY CROP_BUSINESS_KEY ORDER BY COALESCE(CROP_SEASON_BEGIN, CROP_SEASON_END)) AS RK_BEG_END -- noqa
    FROM CHECK_CROP_SEASON CP_BG
    WHERE (CROP_SEASON_BEGIN IS NOT NULL OR CROP_SEASON_END IS NOT NULL)
    --ORDER BY 1, COALESCE(CROP_SEASON_BEGIN,CROP_SEASON_END) -- noqa
),

CROP_SEASON AS (
    SELECT
        A.CROP_BUSINESS_KEY,
        A.CROP_SEASON_BEGIN,
        B.CROP_SEASON_END,
        A.STEP
    FROM CROP_BEG_END AS A
    INNER JOIN CROP_BEG_END AS B
        ON
            A.CROP_BUSINESS_KEY = B.CROP_BUSINESS_KEY
            AND
            (
                A.RK_BEG_END + 1 = B.RK_BEG_END
                OR A.CROP_SEASON_BEGIN = 1
                AND A.CROP_SEASON_END = 1 -- noqa --casos onde tem apenas 1 linha para a mesma chave...
            )
            AND A.CROP_SEASON_BEGIN IS NOT NULL
),

CROP_SEASON_FIRST_LEG AS (
    SELECT -- noqa
        CONCAT(CS.CROP_SEASON_BEGIN ,'-', CS.CROP_SEASON_END, '-', MB.CROP_BUSINESS_KEY) AS CROP_UNIQUE_KEY, -- noqa
        MB.CROP_BUSINESS_KEY,
        CS.STEP,
        CS.CROP_SEASON_BEGIN AS CROP_SEASON_BEGIN_ID,
        CS.CROP_SEASON_END AS CROP_SEASON_END_ID,
        MB.PRODUCT_CODE,
        MB.TRANSSHIPMENT_LOCATION,
        MB.PORT_LOCATION,
        MB.LOCATION_CODE,
        MAX(
            CASE
                WHEN MB.RK = CS.CROP_SEASON_BEGIN -- noqa
                THEN MB.INVOICE_ISSUANCE_DATE -- noqa
            END
        ) AS CROP_SEASON_BEG_DT,
        MAX( -- noqa
            CASE
                WHEN MB.RK = CS.CROP_SEASON_END -- noqa
                THEN MB.INVOICE_ISSUANCE_DATE -- noqa
            END
        ) AS CROP_SEASON_END_DT,
        SUM(
            IFF(STEP = 'FIRST', INVOICE_VOLUME, 0)
        ) AS INVOICE_VOLUME_FIRST,
        SUM(
            IFF(STEP = 'ONLY_SECOND', INVOICE_VOLUME, 0)
        ) AS INVOICE_VOLUME_SEC
    FROM {{ ref('tab_shipment_mass_balance_first_leg_stg') }} AS MB
    INNER JOIN CROP_SEASON AS CS
        ON
            MB.CROP_BUSINESS_KEY = CS.CROP_BUSINESS_KEY 
            AND MB.RK >= CS.CROP_SEASON_BEGIN
            AND MB.RK <= CS.CROP_SEASON_END
    GROUP BY
        1, 2, 3, 4, 5, 6, 7, 8, 9
),

CROP_SEASON_SEC_LEG AS (
    SELECT -- noqa
        MB.CROP_UNIQUE_KEY,
        MB.CROP_BUSINESS_KEY,
        'SECOND' AS STEP,
        MB.CROP_SEASON_BEGIN_ID,
        MB.CROP_SEASON_END_ID,
        SL.PRODUCT_CODE,
        SL.TRANSSHIPMENT_LOCATION,
        SL.PORT_LOCATION,
        SL.LOCATION_CODE ,
        MB.CROP_SEASON_BEG_DT,
        MB.CROP_SEASON_END_DT,
        NULL AS INVOICE_VOLUME_FIRST, --Invoice volume first leg -- noqa
        SUM(SL.INVOICE_VOLUME) AS INVOICE_VOLUME_SEC  --Invoice volume second leg   -- noqa
    FROM CROP_SEASON_FIRST_LEG AS MB
    INNER JOIN {{ ref('tab_shipment_mass_balance_sec_leg_stg') }} AS SL
        ON
            SL.CROP_BUSINESS_KEY = MB.CROP_BUSINESS_KEY
            AND SL.INVOICE_ISSUANCE_DATE >= MB.CROP_SEASON_BEG_DT
            AND SL.INVOICE_ISSUANCE_DATE <= DATEADD(DAY, 60, MB.CROP_SEASON_END_DT)
    GROUP BY
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
)

SELECT * FROM CROP_SEASON_FIRST_LEG
UNION
SELECT * FROM CROP_SEASON_SEC_LEG
