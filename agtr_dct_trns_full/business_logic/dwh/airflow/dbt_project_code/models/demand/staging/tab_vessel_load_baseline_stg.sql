-- noqa: disable=RF06
{{
    config(
        materialized='table'
    )
}}

WITH
ACTUAL_BASELINE AS (
    /* Caso seja a primeira execução, a tabela do modelo ainda não existe */
    {% set exists_table = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.table) %} -- noqa
    {% if not exists_table %}
        SELECT
            NULL AS VESSELID,
            NULL AS "DATE",
            NULL AS REFERENCEDATE,
            NULL AS ITEMID,
            NULL AS LOADEDQUANTITY,
            NULL AS UOM,
            NULL AS FONTE
    /* Caso a tabela exista, referencia ela mesma */
    {% else %}
        SELECT DISTINCT *
        FROM {{ this }}

    {% endif %}
),

NEW_BASELINE AS (
    /* Caso seja a primeira execução/ criação da tabela necessário rodar este
    trecho para ter a carga inicial */
    SELECT DISTINCT
        COALESCE(NULLIF(VESSELID, ''), 'N/A') AS VESSELID,
        COALESCE(DATE, 'N/A') AS "DATE",
        CASE
            WHEN (
                TO_NUMBER(TO_CHAR(CURRENT_DATE(), 'DD')) = 1
                AND DAYOFWEEK(CURRENT_DATE()) != 1
            )
                THEN TO_CHAR(CURRENT_DATE(), 'DD-MM-YYYY')
            ELSE
                TO_CHAR(DATEADD(
                    'day', 1 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()
                ), 'DD-MM-YYYY')
        END AS REFERENCEDATE,
        COALESCE(NULLIF(ITEMID, ''), 'N/A') AS ITEMID,
        COALESCE(LOADEDQUANTITY::DECIMAL(20, 3), 0) AS LOADEDQUANTITY,
        COALESCE(NULLIF(UOM, ''), 'N/A') AS UOM
    FROM {{ ref('vw_embarque_vesselload_stg') }}
    WHERE
        1 = 1
        AND TO_DATE(DATE, 'DD-MM-YYYY') >= TO_DATE(
            TO_CHAR(DATEADD(
                'day', 1 - DAYOFWEEK(CURRENT_DATE()), CURRENT_DATE()
            ), 'DD-MM-YYYY'), 'DD-MM-YYYY'
        )
        OR (
            TO_DATE(DATE, 'DD-MM-YYYY') >= CURRENT_DATE()
            AND TO_NUMBER(TO_CHAR(CURRENT_DATE(), 'DD')) = 1
            AND DAYOFWEEK(CURRENT_DATE()) != 1
        )
),

VESSEL AS (
    SELECT
        COALESCE(ACTUAL.VESSELID, NEW.VESSELID) AS VESSELID,
        COALESCE(ACTUAL.DATE, NEW.DATE) AS "DATE",
        COALESCE(ACTUAL.REFERENCEDATE, NEW.REFERENCEDATE) AS REFERENCEDATE,
        COALESCE(ACTUAL.ITEMID, NEW.ITEMID) AS ITEMID,
        COALESCE(ACTUAL.LOADEDQUANTITY, NEW.LOADEDQUANTITY) AS LOADEDQUANTITY,
        COALESCE(ACTUAL.UOM, NEW.UOM) AS UOM,
        CASE
            WHEN ACTUAL.VESSELID IS NULL
                THEN 'NEW'
            ELSE 'ACTUAL'
        END AS FONTE
    FROM NEW_BASELINE AS NEW
    LEFT JOIN ACTUAL_BASELINE AS ACTUAL
        ON
            NEW.VESSELID = ACTUAL.VESSELID
            AND NEW.ITEMID = ACTUAL.ITEMID
            AND NEW.DATE = ACTUAL.DATE
            AND NEW.REFERENCEDATE = ACTUAL.REFERENCEDATE
            /* caso seja segunda feira até 12:00 BRT, ou caso seja o primeiro
            dia do mês pega o NEW caso contrário pega o dado atual dela mesma
            para não atualizar */
            AND DAYOFWEEK(CURRENT_DATE) != 1
            OR (
                (
                    DAYOFWEEK(CURRENT_DATE) = 1
                    OR TO_CHAR(CURRENT_DATE(), 'DD') != '01'
                )
                AND TO_CHAR(CURRENT_TIMESTAMP, 'HH24:MI:SS') > '07:00:00'
            )
)

SELECT DISTINCT
    *,
    HASH(*) AS HASH_ID
FROM VESSEL
WHERE
    1 = 1
    AND {{ date_max_filter('DATE','DD-MM-YYYY', 'na') }} --noqa
    AND {{ date_max_filter('REFERENCEDATE','DD-MM-YYYY', 'na') }} --noqa
