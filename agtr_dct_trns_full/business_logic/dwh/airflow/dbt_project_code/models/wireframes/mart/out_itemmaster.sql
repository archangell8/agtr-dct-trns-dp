-- noqa: disable=RF06
{{
    config(
        materialized='table',
        tags=['master']
    )
}}

WITH
ITEM_MASTER AS (
    SELECT DISTINCT
        ITEM,
        BASEUOM AS ITEM_BASE_UOM,
        RESOURCE,
        ITEMSTATUS AS ITEM_STATUS,
        ITEMCLASS AS ITEM_CLASS,
        ITEMSTAGE AS ITEM_STAGE,
        ITEM_TYPE,
        L1,
        L2,
        L3,
        '' AS L4,
        '' AS L5,
        '' AS L6,
        '' AS PLANNING_ITEM,
        '' AS REPORTING_ITEM,
        '' AS SEGMENTATION_CATEGORY,
        'All' AS ALL_ITEM,
        IFF(PACKAGESIZE = 'N/A', NULL, PACKAGESIZE) AS PACKAGE_SIZE,
        CONCAT(ITEM, ' - ', ITEMNAME) AS ITEM_DISPLAYNAME,
        CASE
            WHEN L1 = 'MILHO' THEN '#FFD700'
            WHEN L1 = 'SOJA' THEN '#009E60'
            WHEN L1 IN ('FARELO HI-PRO', 'FARELO 46', 'FARELO LO-PRO')
                THEN '#FA8072'
        END AS MEMBERDISPLAYCOLOR,
        CASE
            WHEN L1 IN ('SOJA', 'MILHO')
                THEN TO_CHAR(DATE_TRUNC('YEAR', CURRENT_DATE()), 'DD-MON-YY')
        END AS CROP_DATE
    FROM {{ ref('item_master') }}
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM ITEM_MASTER
