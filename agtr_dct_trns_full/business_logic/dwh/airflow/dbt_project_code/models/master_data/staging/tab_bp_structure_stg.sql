{{
    config(
        materialized='table'
    )
}}

WITH
CTE_UDC_MAPPING AS (
    SELECT
        CATEGORY,
        STAGE,
        SOURCE_CODE,
        TARGET_CODE,
        TARGET_NUMBER
    FROM {{ source('pscfl', 'F_MIN_DCT_UDC') }}
    WHERE
        1 = 1
        AND STATUS = 'ATIVO'
),

BP_STRUCTURE AS (
    SELECT
        BP.LOCATIONID,
        GRP.ORIGINATION_STRUCTURE AS LOCATION_UNIT_STRUCTURE,
        BP.ADDRESS_NUMBER,
        GRP.UNIT_ID,
        BP.ISACTIVE,
        IBP.ATIVO_IBP,
        BP.CNPJ,
        COALESCE(
            CODE.TARGET_CODE,
            NULLIF(IBP.CODE, '0'),
            BP.LOCATION_SUB_REGION
        ) AS LOCATION_CODE,
        CASE
            WHEN LEFT(TRIM(BP.LOCATIONID), 5) = '02191' THEN 'FÍSICA'
            ELSE BP.LOCATION_TYPE
        END AS LOCATION_TYPE
    FROM {{ ref('vw_location_branchplant_stg') }} AS BP
    INNER JOIN {{ source('pscfl', 'F_MIN_ATIVO_IBP') }} AS IBP
        ON BP.LOCATIONID = IBP.BP_ENTREGA_SLIP
    LEFT JOIN {{ source('pscfl', 'F_MIN_LOCATION_UNIT') }} AS UNIT
        ON BP.LOCATIONID = UNIT.BP_COD
    LEFT JOIN {{ source('pscfl', 'F_MIN_LOCATION_OPERATOR') }} AS OP
        ON IBP.CODE = OP.MODAL
    LEFT JOIN {{ source('pscfl', 'F_MIN_LOCATION_AGRUPADA') }} AS GRP
        ON UNIT.UNIT_BASE = GRP.UNIT_ID
    LEFT JOIN CTE_UDC_MAPPING AS CODE
        ON
            UPPER(TRIM(IBP.CODE)) = CODE.SOURCE_CODE
            AND CODE.CATEGORY = 'LOCATION_CODE'
            AND CODE.STAGE = 'DESTINATION'
)

SELECT * FROM BP_STRUCTURE
