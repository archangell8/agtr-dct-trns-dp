-- noqa: disable=all
{% set keys = [
    'bp'
    ]
%}

{%
    set another_columns = [
        'location', 'all_location_bp', 'origin_subregion', 'status', 'destination_unit_id',
        'location_code', 'location_type', 'destination_ibge_id', 'origin_filial_expense',
        'bp_displayname', 'location_displayname', 'address_book', 'address_book_displayname',
        'destination_displayname', 'location_unit_structure'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_locationbpmaster') }}"
] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['master'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.BP,
        S.BP_DISPLAYNAME,
        S.DESTINATION_IBGE_ID,
        S.DESTINATION,
        S.DESTINATION_DISPLAYNAME,
        S.LOCATION_CODE,
        S.LOCATION_TYPE,
        S.ORIGIN_FILIAL_EXPENSE,
        S.LOCATION,
        S.LOCATION_UNIT_STRUCTURE,
        S.LOCATION_DISPLAYNAME,
        S.ALL_LOCATION_BP,
        S.ORIGIN_SUBREGION,
        S.STATUS,
        S.ADDRESS_BOOK,
        S.ADDRESS_BOOK_DISPLAYNAME,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_locationbpmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_locationbpmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_locationbpmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}