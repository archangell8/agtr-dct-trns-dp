-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'item'
] %}
{% set list_another_columns = [
    'itemname', 'itemstatus', 'itemclass', 'itemstage', 'item_type', 'l1', 'l2',
    'l3', 'baseuom', 'baseuomdescription', 'resource', 'containersize',
    'packagesize'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
ITEM_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_item_stg') }}
    QUALIFY RN = 1
),

ITEM AS (
    SELECT
        S.ITEM,
        S.ITEMNAME,
        S.ITEMSTATUS,
        S.ITEMCLASS,
        S.ITEMSTAGE,
        S.ITEM_TYPE,
        S.L1,
        S.L2,
        S.L3,
        S.BASEUOM,
        S.BASEUOMDESCRIPTION,
        S.RESOURCE AS "RESOURCE",
        S.CONTAINERSIZE,
        S.PACKAGESIZE,
        S.HASH_ID
    FROM ITEM_STG AS S
)

SELECT *
FROM ITEM
