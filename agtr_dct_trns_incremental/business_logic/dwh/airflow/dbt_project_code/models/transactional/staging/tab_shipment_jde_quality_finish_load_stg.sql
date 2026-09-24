-- noqa: disable=ST09
{{
    config(
        materialized='table'
    )
}}


WITH
SHIPMENT_LOAD AS (
    SELECT DISTINCT LOADNUMBER
    FROM {{ ref('shipment_details_master') }}
),

FINISH_LOAD AS (
    SELECT
        'RECEPCAO' AS EVENTO,
        F49621.TDKCOO AS CIA,
        TO_CHAR(F49621.TDLDNM) AS LOADNUMBER,
        F49621.TDVMCU AS BP,
        F49621.TDDOCO AS NRPEDIDO,
        F49621.TDLNID AS LINPEDIDO,
        F42.SDRORN AS NRDOCRELACIONADO,
        F55Z.ZZDOCO AS LOADQUALIDADE,
        F55Z.ZZDCTO AS TPDOCQUALIDADE,
        F0005.DRDL01 AS DESCRICAO,
        CASE
            WHEN F55Z.ZZQTST LIKE '%UMIDADE%' THEN 'UMIDADE'
            WHEN F55Z.ZZQTST LIKE '%IMPUREZA%' THEN 'IMPUREZA'
            WHEN F55Z.ZZQTST LIKE '%AVARIADO%' THEN 'AVARIADOS'
        END AS IDTESTQUALIDADE,
        TRY_CAST(
            IFF(
                REPLACE(TRIM(F55Z.ZZQVAL), ',', '.') = '',
                NULL,
                '0' || REPLACE(TRIM(F55Z.ZZQVAL), ',', '.')
            ) AS FLOAT
        ) AS TESTQUALIDADE,
        {{ julian_date_to_gregorian('F55Z', 'ZZUPMJ') }} AS DATAQUALIDADE, -- noqa
        F55Z.ZZRSUM AS RESUM_QUALIDADE,
        F42.SDLITM AS CODIGOPRODUTO
    FROM {{ source('jde', 'F4960') }} AS F49
    INNER JOIN {{ source('jde', 'F49621') }} AS F49621
        ON
            F49.TMLDNM = F49621.TDLDNM
            AND F49.TMVMCU = F49621.TDVMCU
    INNER JOIN {{ source('jde', 'F4211') }} AS F42
        ON
            F49621.TDKCOO = F42.SDKCOO
            AND F49621.TDDOCO = F42.SDDOCO
            AND F49621.TDDCTO = F42.SDDCTO
            AND F49621.TDLNID = F42.SDLNID
            AND COALESCE(F42.SDURAB, F49621.TDLDNM) = F49621.TDLDNM
    INNER JOIN {{ source('jde', 'F553711Z') }} AS F55Z
        ON
            F55Z.ZZDOCO = F49.TMLDNM
            AND F55Z.ZZDCTO LIKE 'O%'
    INNER JOIN {{ source('jde', 'PRODCTL_F0005') }} AS F0005
        ON
            TRIM(F0005.DRKY) = F55Z.ZZDCTO
            AND F0005.DRSY = '00'
            AND F0005.DRRT = 'DT'
    INNER JOIN SHIPMENT_LOAD AS SL
        ON SL.LOADNUMBER = F49621.TDLDNM
    WHERE
        1 = 1
        AND F42.SDKCOO IN ('52171', '52191', '52180')
        AND F49.TMLDNM > 0
        AND F49.TMLOAD >= 125000
        AND F49.TMLDLS IN ('80', '90', '98')
        AND {{ filter_remove_jde_delete_data('F49') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F49621') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F42') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F55Z') }} -- noqa
        AND {{ filter_remove_jde_delete_data('F0005') }} -- noqa
)

SELECT
    EVENTO,
    CIA,
    LOADNUMBER,
    BP,
    LOADQUALIDADE,
    IDTESTQUALIDADE,
    MAX(TESTQUALIDADE) AS TESTQUALIDADE,
    MAX(DATAQUALIDADE) AS DATAQUALIDADE,
    TRIM(CODIGOPRODUTO) AS CODIGOPRODUTO
FROM FINISH_LOAD
WHERE IDTESTQUALIDADE IS NOT NULL
GROUP BY
    1, 2, 3, 4, 5, 6, 9
