-- noqa: disable=RF06,RF04
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
SOURCING_CONTRACT AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'SourcingContract' AS RESOURCE_TYPE,
        CONTRACT_LINEID AS RESOURCE,
        'SourcingContract' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('out_sourcingcontractdetails') }}
),

DISTRIBUTION_LOADING AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'Distribution Loading' AS RESOURCE_TYPE,
        CONCAT('Loading_Resource_', A.LOCATION_FROM, '_', B.TRANSMODETYPE)
            AS RESOURCE,
        'Distribution Loading' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('transmode_master') }} AS B
        ON A.TRANSMODE = B.TRANSMODE
    WHERE
        A.LOCATION_FROM_UNIT_STRUCTURE IN (
            'ARMAZÉM', 'PORTO FLUVIAL', 'TRANSBORDO', 'PONTO DE COLETA'
        )
),

DISTRIBUTION_UNLOADING AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'Distribution UnLoading' AS RESOURCE_TYPE,
        CONCAT('UnLoading_Resource_', A.LOCATION_TO, '_', B.TRANSMODETYPE)
            AS RESOURCE,
        'Distribution UnLoading' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('transmode_master') }} AS B
        ON A.TRANSMODE = B.TRANSMODE
    WHERE
        A.LOCATION_TO_UNIT_STRUCTURE IN (
            'FÁBRICA', 'PORTO FLUVIAL', 'TRANSBORDO', 'MERCADO INTERNO'
        )
),

DISTRIBUTION_UNLOADING_PORTO_MARITIMO AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'Distribution UnLoading' AS RESOURCE_TYPE,
        CONCAT(
            'UnLoading_Resource_',
            A.LOCATION_TO,
            '_',
            B.TRANSMODETYPE,
            '_',
            ITEM.L1
        ) AS RESOURCE,
        'Distribution UnLoading' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('transmode_master') }} AS B
        ON A.TRANSMODE = B.TRANSMODE
    INNER JOIN {{ ref('itemlanetransmode_master') }} AS ILT
        ON A.LANEID = ILT.BODLANEID
    LEFT JOIN {{ ref('item_master') }} AS ITEM
        ON ILT.ITEMID = ITEM.ITEMSTAGE
    WHERE
        A.LOCATION_TO_UNIT_STRUCTURE IN ('PORTO MARÍTIMO')
),

TRANSPORTATION_CONTRACT_SOURCE AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'Transportation Contract' AS RESOURCE_TYPE,
        CONCAT('Resource_TransContract_', A.LOCATION_FROM, '_', ITEM.L1)
            AS RESOURCE,
        'Transportation Contract' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('itemlanetransmode_master') }} AS ILT
        ON A.LANEID = ILT.BODLANEID
    LEFT JOIN {{ ref('item_master') }} AS ITEM
        ON ILT.ITEMID = ITEM.ITEMSTAGE
    WHERE
        A.LOCATION_FROM_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
),

-- Transportation Contract Resources (Destination - Porto Fluvial/Transbordo)
TRANSPORTATION_CONTRACT_DESTINATION AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'Transportation Contract' AS RESOURCE_TYPE,
        CONCAT('Resource_TransContract_', A.LOCATION_TO, '_', ITEM.L1)
            AS RESOURCE,
        'Transportation Contract' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('itemlanetransmode_master') }} AS ILT
        ON A.LANEID = ILT.BODLANEID
    LEFT JOIN {{ ref('item_master') }} AS ITEM
        ON ILT.ITEMID = ITEM.ITEMSTAGE
    WHERE
        A.LOCATION_TO_UNIT_STRUCTURE IN ('PORTO FLUVIAL', 'TRANSBORDO')
),

-- Transportation Contract Resources (Porto Marítimo - Location Code)
TRANSPORTATION_CONTRACT_PORTO_MARITIMO AS (
    SELECT DISTINCT
        'Distribution' AS RESOURCE_ALTERNATE_GROUP2,
        'Transportation Contract' AS RESOURCE_TYPE,
        CONCAT('Resource_TransContract_', B.LOCATION_CODE) AS RESOURCE,
        'Transportation Contract' AS RESOURCE_ALTERNATE_GROUP1,
        'All' AS RESOURCE_ALL
    FROM {{ ref('lane_master') }} AS A
    INNER JOIN {{ ref('location_master') }} AS B
        ON A.LOCATION_TO = B.LOCATIONID
    WHERE
        A.LOCATION_TO_UNIT_STRUCTURE = 'PORTO MARÍTIMO'
),

-- Union all resources
RESOURCE_UNION AS (
    SELECT * FROM SOURCING_CONTRACT
    UNION DISTINCT
    SELECT * FROM DISTRIBUTION_LOADING
    UNION DISTINCT
    SELECT * FROM DISTRIBUTION_UNLOADING
    UNION DISTINCT
    SELECT * FROM DISTRIBUTION_UNLOADING_PORTO_MARITIMO
    UNION DISTINCT
    SELECT * FROM TRANSPORTATION_CONTRACT_SOURCE
    UNION DISTINCT
    SELECT * FROM TRANSPORTATION_CONTRACT_DESTINATION
    UNION DISTINCT
    SELECT * FROM TRANSPORTATION_CONTRACT_PORTO_MARITIMO
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM RESOURCE_UNION
