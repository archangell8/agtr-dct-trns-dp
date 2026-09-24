-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full', 'delta_execution', 'delta_onhands', 'delta_vessel'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'ITEM' AS ITEM,
        'ITEMNAME' AS ITEMNAME,
        'ITEMSTATUS' AS ITEMSTATUS,
        'ITEMCLASS' AS ITEMCLASS,
        'ITEMSTAGE' AS ITEMSTAGE,
        'ITEM_TYPE' AS ITEM_TYPE,
        'L1' AS L1,
        'L2' AS L2,
        'L3' AS L3,
        'BASEUOM' AS BASEUOM,
        'BASEUOMDESCRIPTION' AS BASEUOMDESCRIPTION,
        'RESOURCE' AS "RESOURCE", --noqa
        'CONTAINERSIZE' AS CONTAINERSIZE,
        'PACKAGESIZE' AS PACKAGESIZE,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('item')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('item')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        ITEM::STRING,
        ITEMNAME::STRING,
        ITEMSTATUS::STRING,
        ITEMCLASS::STRING,
        ITEMSTAGE::STRING,
        ITEM_TYPE::STRING,
        L1::STRING,
        L2::STRING,
        L3::STRING,
        BASEUOM::STRING,
        BASEUOMDESCRIPTION::STRING,
        RESOURCE::STRING,
        CONTAINERSIZE::STRING,
        PACKAGESIZE::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('item') }}
    {% if check_model_group_scheduler(list_tags, 'Item') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    ITEM,
    ITEMNAME,
    ITEMSTATUS,
    ITEMCLASS,
    ITEMSTAGE,
    ITEM_TYPE,
    L1,
    L2,
    L3,
    BASEUOM,
    BASEUOMDESCRIPTION,
    RESOURCE,
    CONTAINERSIZE,
    PACKAGESIZE,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
