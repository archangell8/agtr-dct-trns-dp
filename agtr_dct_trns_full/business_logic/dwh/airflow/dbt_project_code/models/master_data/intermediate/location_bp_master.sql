-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'bp_number'
] %}
{% set list_another_columns = [
    'bp_name', 'origin_subregion', 'origin_unit_name', 'origin_unit_id',
    'destination_unit_name', 'destination_unit_id', 'destination_ibge_id',
    'address_book', 'location_code', 'location_type', 'status',
    'origin_filial_expense'
] %}

{{
    config(
        materialized = 'table',
        tags = []
    )
}}

WITH
LOCATION_BP_STG AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY {{ list_keys | join(', ') }} ORDER BY HASH_ID
        ) AS RN
    FROM {{ ref('vw_location_bp_stg') }}
    QUALIFY RN = 1
),

LOCATION_BP AS (
    SELECT
        S.BP_NUMBER,
        S.BP_NAME,
        S.ORIGIN_SUBREGION,
        S.ORIGIN_UNIT_NAME,
        S.ORIGIN_UNIT_ID,
        S.DESTINATION_UNIT_NAME,
        S.DESTINATION_UNIT_ID,
        S.DESTINATION_IBGE_ID,
        S.ADDRESS_BOOK,
        S.LOCATION_CODE,
        S.STATUS,
        S.LOCATION_TYPE,
        S.ORIGIN_FILIAL_EXPENSE,
        S.HASH_ID
    FROM LOCATION_BP_STG AS S
)

SELECT *
FROM LOCATION_BP
