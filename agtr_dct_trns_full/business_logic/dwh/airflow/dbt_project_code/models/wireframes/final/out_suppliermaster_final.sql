-- noqa: disable=all
{% set keys = [
    'supplier_location'
    ]
%}

{%
    set another_columns = [
        'address', 'complement', 'neighborhood', 'zipcode', 'supplier', 'taxid',
        'status', 'city', 'state', 'country', 'market', 'territory', 'segmentation',
        'suppliergroup', 'creditblocked', 'all_supplier', 'supplier_location_type',
        'supplier_location_displayname', 'supplier_displayname'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_suppliermaster') }}"
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
        S.SUPPLIER_LOCATION,
        S.ADDRESS,
        S.COMPLEMENT,
        S.NEIGHBORHOOD,
        S.ZIPCODE,
        S.SUPPLIER,
        S.TAXID,
        S.STATUS,
        S.CITY,
        S.STATE,
        S.COUNTRY,
        S.MARKET,
        S.TERRITORY,
        S.SEGMENTATION,
        S.SUPPLIERGROUP,
        S.CREDITBLOCKED,
        S.ALL_SUPPLIER,
        S.SUPPLIER_LOCATION_TYPE,
        S.SUPPLIER_LOCATION_DISPLAYNAME,
        S.SUPPLIER_DISPLAYNAME,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_suppliermaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_suppliermaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_suppliermaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}