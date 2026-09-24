-- noqa: disable=RF06,ST09
{{
    config(
        materialized='table'
    )
}}

WITH
TAB_ONHANDS_ESTOQUE_PORTO AS (
    /* Caso seja a primeira execução, a tabela do modelo ainda não existe */
    {% set exists_table = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.table) %} -- noqa
    {% if not exists_table %}
        SELECT
            'N/A' AS ITEM,
            'N/A' AS BP,
            'N/A' AS "LOCATION",
            'N/A' AS UOM,
            'N/A' AS "DAY",
            NULL AS COMPANY,
            NULL AS BLOCKEDQUANTITY,
            NULL AS ONHANDQUANTITY,
            NULL AS QUARANTINEQUANTITY

    /* Caso a tabela exista, referencia ela mesma */
    {% else %}
        SELECT *
        FROM {{ this }}

    {% endif %}
),

ONHANDS_ESTOQUE_PORTO_STG AS (
    SELECT
        IT.ITEM,
        0 AS BLOCKEDQUANTITY,
        0 AS QUARANTINEQUANTITY,
        'TN' AS UOM,
        TRIM(F_MIN_INVENTARIO_PORTO.LOCATION) AS "LOCATION",
        -- DATEADD(
        --     'HOUR',
        --     REPLACE(LOC_GROUP.TIMEZONE, ':00')::INT * -1,
        --     F_MIN_INVENTARIO_PORTO.DIA
        -- ) AS "DAY",
        CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP) AS "DAY",
        COALESCE(
            REPLACE(F_MIN_INVENTARIO_PORTO.VOLUME, ',', '.'), 0
        ) AS ONHANDQUANTITY,
        UPPER(CASE
            WHEN F_MIN_INVENTARIO_PORTO.DESCRICAO = 'Nutrade'
                THEN 'Nutrade'
            ELSE COALESCE(F_MIN_INVENTARIO_PORTO.SHIPPER, 'N/A')
        END) AS COMPANY
    FROM {{ source('pscfl', 'F_MIN_INVENTARIO_PORTO') }} AS F_MIN_INVENTARIO_PORTO -- noqa
    INNER JOIN {{ ref('location_master') }} AS LCT
        ON LCT.LOCATIONID = TRIM(F_MIN_INVENTARIO_PORTO.LOCATION)
    LEFT JOIN {{ source('pscfl', 'F_MIN_LOCATION_AGRUPADA') }} AS LOC_GROUP
        ON LCT.LOCATIONID = LOC_GROUP.UNIT_ID
    INNER JOIN {{ ref('item_master') }} AS IT
        ON IT.ITEM = F_MIN_INVENTARIO_PORTO.PRODUCT
    WHERE
        1 = 1
        AND LCT.LOCATIONID IS NOT NULL
),

ONHANDS_ESTOQUE_PORTO AS (
    SELECT
        ITEM,
        BLOCKEDQUANTITY,
        QUARANTINEQUANTITY,
        UOM,
        "LOCATION",
        "DAY",
        COMPANY,
        SUM(ONHANDQUANTITY) AS ONHANDQUANTITY
    FROM ONHANDS_ESTOQUE_PORTO_STG
    WHERE
        1 = 1
    GROUP BY
        ITEM,
        BLOCKEDQUANTITY,
        QUARANTINEQUANTITY,
        UOM,
        "LOCATION",
        "DAY",
        COMPANY
),

ONHANDS_ESTOQUE_PORTO_FINAL AS (
    /*
        Verifica se o horário da execução está dentro do horário de
        fechamento da planta. O horário de fechamento da planta será
        o valor da coluna hr_begin_onhands da tabela F_MIN_LOCATION_agrupada
        + 1 hora. Caso a hora corrente seja menor ou igual, atualiza
        esse registro, caso não, mantem o valor do registro anterior.
    */
    SELECT -- noqa
        CASE
            WHEN OH_STG.ITEM IS NULL OR OH_TIME.ITEM IS NOT NULL
                THEN OH.ITEM
            ELSE OH_STG.ITEM
        END AS ITEM,
        CASE
            WHEN OH_STG.LOCATION IS NULL OR OH_TIME.LOCATION IS NOT NULL
                THEN OH.LOCATION
            ELSE OH_STG.LOCATION
        END AS "LOCATION",
        CASE
            WHEN OH_STG.UOM IS NULL OR OH_TIME.UOM IS NOT NULL
                THEN OH.UOM
            ELSE OH_STG.UOM
        END AS UOM,
        CASE
            WHEN OH_STG.DAY IS NULL OR OH_TIME.DAY IS NOT NULL
                THEN TO_CHAR(OH."DAY", 'DD-MM-YYYY HH24:MI:SS')
            ELSE OH_STG.DAY
        END AS "DAY",
        UPPER(CASE
            WHEN OH_STG.COMPANY IS NULL OR OH_TIME.COMPANY IS NOT NULL
                THEN OH.COMPANY
            ELSE OH_STG.COMPANY
        END) AS COMPANY,
        CASE
            WHEN OH_STG.BLOCKEDQUANTITY IS NULL OR OH_TIME.BLOCKEDQUANTITY IS NOT NULL -- noqa
                THEN OH.BLOCKEDQUANTITY
            ELSE OH_STG.BLOCKEDQUANTITY
        END AS BLOCKEDQUANTITY,
        CASE
            WHEN OH_STG.ONHANDQUANTITY IS NULL OR OH_TIME.ONHANDQUANTITY IS NOT NULL -- noqa
                THEN OH.ONHANDQUANTITY
            ELSE OH_STG.ONHANDQUANTITY
        END AS ONHANDQUANTITY,
        CASE
            WHEN OH_STG.QUARANTINEQUANTITY IS NULL OR OH_TIME.QUARANTINEQUANTITY IS NOT NULL -- noqa
                THEN OH.QUARANTINEQUANTITY
            ELSE OH_STG.QUARANTINEQUANTITY
        END AS QUARANTINEQUANTITY,
        LOC_GROUP.HR_BEGIN_ONHANDS,
        LOC_GROUP.TIMEZONE
    FROM ONHANDS_ESTOQUE_PORTO AS OH
    INNER JOIN {{ source('pscfl', 'F_MIN_LOCATION_AGRUPADA') }} AS LOC_GROUP -- noqa
        ON OH.LOCATION = LOC_GROUP.UNIT_ID
    /*
        Join para recuperar as atuais informações da tabela {{ this }} e compor
        todas as colunas caso não seja o horário de atualização da planta.
    */
    LEFT JOIN TAB_ONHANDS_ESTOQUE_PORTO AS OH_STG
        ON
            OH.ITEM = OH_STG.ITEM
            AND OH.LOCATION = OH_STG.LOCATION
            AND OH.COMPANY = OH_STG.COMPANY
    /*
        Join para verificar se o horário atual corresponde ao horário de
        atualização da planta. Para o caso do estoque portos, caso seja o
        horário de 12:00h, atualizar da mesma forma.
    */
    LEFT JOIN ONHANDS_ESTOQUE_PORTO_STG AS OH_TIME
        ON
            OH.ITEM = OH_TIME.ITEM
            AND OH.LOCATION = OH_TIME.LOCATION
            AND OH.COMPANY = OH_TIME.COMPANY
            AND (
                /*
                    Recupera a hora atual no timezone da planta analisada, e
                    verifica se esse horário é igual ao horário da coluna begin
                    of onhands.
                */
                TO_TIME(DATEADD('HOUR', REPLACE(LOC_GROUP.TIMEZONE, ':00')::INT, CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP))) -- noqa
                <= DATEADD('MINUTES', 59, TO_TIME(LOC_GROUP.HR_BEGIN_ONHANDS)) -- noqa
                OR
                TO_TIME(CONVERT_TIMEZONE('America/Sao_Paulo', CURRENT_TIMESTAMP)) -- noqa
                BETWEEN TO_TIME('12:00:00') AND TO_TIME('12:59:00') -- noqa
            )
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM ONHANDS_ESTOQUE_PORTO_FINAL
WHERE
    1 = 1
