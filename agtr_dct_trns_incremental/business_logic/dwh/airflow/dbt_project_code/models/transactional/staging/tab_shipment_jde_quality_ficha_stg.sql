-- noqa: disable=ST09
{{
    config(
        materialized='table'
    )
}}

WITH JDE_QUALIDADE_RECEPCAO AS (
    SELECT
        'RECEPCAO' AS EVENTO,
        T0.PDKCOO AS CIA,
        T0.PDMCU AS BP,
        T0.PDDOCO AS FICHA,
        T0.PDLNID AS LINHAFICHA,
        T4.ZZDOCO AS DOCQUALIDADE,
        T4.ZZDCTO AS TPDOCQUALIDADE,
        T5.DRDL01 AS DESCRICAO,
        CASE
            WHEN T4.ZZQTST LIKE '%UMIDADE%' THEN 'UMIDADE'
            WHEN T4.ZZQTST LIKE '%IMPUREZA%' THEN 'IMPUREZA'
            WHEN T4.ZZQTST LIKE '%AVARIADO%' THEN 'AVARIADOS'
        END AS IDTESTQUALIDADE,
        TRY_CAST(
            IFF(
                REPLACE(TRIM(T4.ZZQVAL), ',', '.') = '',
                NULL,
                '0' || REPLACE(TRIM(T4.ZZQVAL), ',', '.')
            ) AS FLOAT
        ) AS TESTQUALIDADE,
        T4.ZZRSUM AS RESUM_QUALIDADE,
        {{ julian_date_to_gregorian('T4', 'ZZUPMJ') }} AS DATAQUALIDADE, -- noqa
        T0.PDVR02 AS LOTID,
        T0.PDLITM AS CODIGOPRODUTO
    FROM {{ source('jde', 'F4311') }} AS T0
    INNER JOIN {{ source('jde', 'F553711Z') }} AS T4
        ON
            T0.PDDOCO = T4.ZZDOCO
            AND T0.PDKCOO = T4.ZZKCOO
            AND T0.PDDCTO = T4.ZZDCTO
    INNER JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T5
        ON
            T5.DRSY = '00'
            AND T5.DRRT = 'DT'
            AND TRIM(T5.DRKY) = TRIM(T4.ZZDCTO)
    WHERE
        T0.PDLTTR != '980'
        AND {{ filter_remove_jde_delete_data('T4') }} -- noqa
        AND {{ filter_remove_jde_delete_data('T5') }} -- noqa
        AND {{ filter_remove_jde_delete_data('T0') }} -- noqa
        AND T0.PDUPMJ >= 125000
    QUALIFY RANK() OVER(
        PARTITION BY
            T4.ZZDOCO,
            T4.ZZKCOO,
            T4.ZZDCTO,
            CASE
                WHEN T4.ZZQTST LIKE '%UMIDADE%' THEN 'UMIDADE'
                WHEN T4.ZZQTST LIKE '%IMPUREZA%' THEN 'IMPUREZA'
                WHEN T4.ZZQTST LIKE '%AVARIADO%' THEN 'AVARIADOS'
            END
        ORDER BY T4.ZZUPMJ DESC, T4.ZZUPMT DESC, T4.ZZQVAL DESC
    ) = 1

    UNION DISTINCT

    SELECT
        'EXPEDICAO' AS EVENTO,
        T0.PDKCOO AS CIA,
        T0.PDMCU AS BP,
        T0.PDDOCO AS FICHA,
        T0.PDLNID AS LINHAFICHA,
        T8.TRDOCO AS DOCQUALIDADE,
        T8.TRDCTO AS TPDOCQUALIDADE,
        T5.DRDL01 AS DESCRICAO,
        CASE
            WHEN T8.TRQTST LIKE '%UMIDADE%' THEN 'UMIDADE'
            WHEN T8.TRQTST LIKE '%IMPUREZA%' THEN 'IMPUREZA'
            WHEN T8.TRQTST LIKE '%AVARIADO%' THEN 'AVARIADOS'
        END AS IDTESTQUALIDADE,
        TRY_CAST(
            IFF(
                REPLACE(TRIM(T8.TRQVAL), ',', '.') = '',
                NULL,
                '0' || REPLACE(TRIM(T8.TRQVAL), ',', '.')
            ) AS FLOAT
        ) / 100 AS TESTQUALIDADE,
        T8.TRRSUM AS RESUM_QUALIDADE,
        {{ julian_date_to_gregorian('T8', 'TRUPMJ') }} AS DATAQUALIDADE, -- noqa
        T0.PDVR02 AS LOTID,
        T0.PDLITM AS CODIGOPRODUTO
    FROM {{ source('jde', 'F4311') }} AS T0
    INNER JOIN {{ source('jde', 'F3711') }} AS T8
        ON
            T0.PDDOCO = T8.TRDOCO
            AND T0.PDKCOO = T8.TRKCOO
            AND T0.PDDCTO = T8.TRDCTO
            AND T0.PDLNID = T8.TRLNID
    INNER JOIN {{ source('jde', 'PRODCTL_F0005') }} AS T5
        ON
            T5.DRSY = '00'
            AND T5.DRRT = 'DT'
            AND TRIM(T5.DRKY) = TRIM(T8.TRDCTO)
    WHERE
        T0.PDLTTR != '980'
        AND {{ filter_remove_jde_delete_data('T0') }} -- noqa
        AND {{ filter_remove_jde_delete_data('T8') }} -- noqa
        AND {{ filter_remove_jde_delete_data('T5') }} -- noqa
        AND T8.TRUPMJ >= 125000 -- noqa
    QUALIFY RANK() OVER(
        PARTITION BY
            T8.TRDOCO,
            T8.TRKCOO,
            T8.TRDCTO,
            T8.TRLNID,
                CASE
                WHEN T8.TRQTST LIKE '%UMIDADE%' THEN 'UMIDADE'
                WHEN T8.TRQTST LIKE '%IMPUREZA%' THEN 'IMPUREZA'
                WHEN T8.TRQTST LIKE '%AVARIADO%' THEN 'AVARIADOS'
            END
        ORDER BY T8.TRUPMJ DESC, T8.TRTDAY DESC, T8.TRQVAL DESC
    ) = 1
),

SHIP_ID AS (
    SELECT DISTINCT
        S.ID AS SHIPMENTID,
        S.LOADNUMBER,
        S.LINENUMBER
    FROM {{ ref('tab_shipment_details_cif_stg') }} AS S

    UNION DISTINCT

    SELECT DISTINCT
        S.ID AS SHIPMENTID,
        S.LOADNUMBER,
        S.LINENUMBER
    FROM {{ ref('tab_shipment_details_fbz_stg') }} AS S

    UNION DISTINCT

    SELECT DISTINCT
        S.ID AS SHIPMENTID,
        S.LOADNUMBER,
        S.LINENUMBER
    FROM {{ ref('tab_shipment_details_fob_stg') }} AS S

    UNION DISTINCT

    SELECT DISTINCT
        S.ID AS SHIPMENTID,
        S.LOADNUMBER,
        S.LINENUMBER
    FROM {{ ref('tab_shipment_details_venda_stg') }} AS S

    UNION DISTINCT

    SELECT DISTINCT
        S.ID AS SHIPMENTID,
        S.LOADNUMBER,
        NULL AS LINENUMBER
    FROM {{ ref('tab_shipment_details_transf_stg') }} AS S
)

SELECT
    QLTY.EVENTO,
    QLTY.CIA,
    QLTY.BP,
    QLTY.FICHA,
    QLTY.LINHAFICHA,
    QLTY.DOCQUALIDADE,
    QLTY.TPDOCQUALIDADE,
    QLTY.DESCRICAO,
    QLTY.IDTESTQUALIDADE,
    QLTY.TESTQUALIDADE,
    QLTY.RESUM_QUALIDADE,
    QLTY.DATAQUALIDADE,
    QLTY.LOTID,
    QLTY.CODIGOPRODUTO,
    SHIP.SHIPMENTID
FROM JDE_QUALIDADE_RECEPCAO AS QLTY
INNER JOIN SHIP_ID AS SHIP
    ON
        QLTY.FICHA = SHIP.LOADNUMBER
        AND QLTY.LINHAFICHA = SHIP.LINENUMBER
WHERE
    1 = 1
    AND QLTY.CIA IN ('52171', '52191', '52180')
    AND QLTY.FICHA IN (
        SELECT DISTINCT A.LOADNUMBER_RAW
        FROM {{ ref('tab_shipment_details_stg') }} AS A
        UNION DISTINCT
        SELECT DISTINCT B.FICHANUMBER_RAW
        FROM {{ ref('tab_shipment_details_stg') }} AS B
    )
    AND QLTY.IDTESTQUALIDADE IS NOT NULL
