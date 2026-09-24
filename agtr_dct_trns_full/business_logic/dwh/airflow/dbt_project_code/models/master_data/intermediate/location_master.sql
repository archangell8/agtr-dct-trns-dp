-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'locationid'
] %}
{% set list_another_columns = [
    'location_unit_structure', 'location_group', 'location_country',
    'location_region', 'location_sub_region', 'location_name',
    'location_code', 'zip', 'address', 'city', 'longitude',
    'latitude', 'state', 'location_ownership', 'operator',
    'location_ibp_asset', 'isactive', 'restriction', 'routingcomments',
    'location_type'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
LOCATION_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('tab_location_stg') }}
    QUALIFY RN = 1
),

LOCATION_FINAL AS (
    SELECT
        S.LOCATIONID,
        S.LOCATION_UNIT_STRUCTURE,
        S.LOCATION_GROUP,
        S.LOCATION_COUNTRY,
        S.LOCATION_REGION,
        S.LOCATION_SUB_REGION,
        S.LOCATION_NAME,
        S.LOCATION_CODE,
        S.ZIP,
        S.ADDRESS AS "ADDRESS",
        S.ISACTIVE,
        S.CITY,
        S.LONGITUDE,
        S.LATITUDE,
        S.STATE AS "STATE",
        S.LOCATION_OWNERSHIP,
        S.OPERATOR,
        S.LOCATION_IBP_ASSET,
        S.ROUTINGCOMMENTS,
        S.RESTRICTION,
        S.LOCATION_TYPE,
        S.HASH_ID
    FROM LOCATION_STG AS S
)

SELECT *
FROM LOCATION_FINAL
