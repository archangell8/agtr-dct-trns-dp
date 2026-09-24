{{
    config(
        materialized='view'
    )
}}

WITH
UOMC AS (
    SELECT
        'BRE' AS CURRENCYFROM,
        'USM' AS CURRENCYTO,
        D3.CCZ55PMKVR AS CONVERSIONFACTOR,
        D3.CCZ55DTEHR,
        TO_CHAR(
            TO_DATE(SUBSTR(D3.CCZ55DTEHR, 1, 8), 'YYYYMMDD'),
            'DD/MM/YYYY'
        ) AS CONVERSIONSTART,
        TO_CHAR(
            TO_DATE(SUBSTR(D3.CCZ55DTEHR, 1, 8), 'YYYYMMDD'),
            'DD/MM/YYYY'
        ) AS CONVERSIONEND,
        ROW_NUMBER()
            OVER (
                PARTITION BY TO_CHAR(
                    TO_DATE(SUBSTR(D3.CCZ55DTEHR, 1, 8), 'YYYYMMDD'),
                    'DD/MM/YYYY'
                ) ORDER BY D3.CCZ55DTEHR::INT, D3.CCZ55SEQUE::INT DESC
            ) AS RNK
    FROM
        {{ source('jde', 'F5540029') }} AS D3
    WHERE
        1 = 1
        AND D3.CCZ55TABC = 'PTAX80'
        AND TRIM(D3.CCZ55CDCMA) = 'PTAX800'
        AND TRIM(D3.CCZ55COMP) = 'DOLAR'
        AND D3.CCZ55DTCMA BETWEEN
        (
            (YEAR(ADD_MONTHS(CURRENT_DATE(), -6)) - 1900)
            * 1000
            + DAYOFYEAR(ADD_MONTHS(CURRENT_DATE(), -6))
        )
        AND
        (
            (YEAR(CURRENT_DATE()) - 1900)
            * 1000
            + DAYOFYEAR(CURRENT_DATE())
        )
        AND D3.CCZ55COL01 IN ('3', '4')
),

CURRENCY_CONVERSION AS (
    SELECT
        COALESCE(NULLIF(CURRENCYFROM, ''), 'N/A') AS CURRENCYFROM,
        COALESCE(NULLIF(CURRENCYTO, ''), 'N/A') AS CURRENCYTO,
        COALESCE(
            CONVERSIONFACTOR::DECIMAL(20, 3),
            0.00
        ) AS CONVERSIONFACTOR,
        COALESCE(
            TO_CHAR(
                TO_DATE(CONVERSIONSTART, 'DD/MM/YYYY'),
                'DD-MM-YYYY'
            ),
            'N/A'
        ) AS CONVERSIONSTART,
        COALESCE(
            TO_CHAR(
                TO_DATE(CONVERSIONEND, 'DD/MM/YYYY'),
                'DD-MM-YYYY'
            ),
            'N/A'
        ) AS CONVERSIONEND
    FROM UOMC
    WHERE RNK = 1
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM CURRENCY_CONVERSION
WHERE
    1 = 1
    AND {{ date_max_filter('CONVERSIONSTART', 'DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('CONVERSIONEND', 'DD-MM-YYYY', 'na') }} --noqa
