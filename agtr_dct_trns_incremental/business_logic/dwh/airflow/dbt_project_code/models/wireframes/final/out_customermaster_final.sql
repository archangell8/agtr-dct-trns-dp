-- noqa: disable=all
{% set keys = [
    'customer'
    ]
%}

{%
    set another_columns = [
        'address', 'complement', 'neighborhood', 'zipcode', 'taxid', 'status',
        'city', 'state', 'country', 'market', 'territory', 'segmentation',
        'customergroup', 'creditblocked', 'allcustomer', 'cmm_crush_cidadedestino',
        'customerdisplayname', 'customer_city', 'customer_displayname'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_customermaster') }}"
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
        S.CUSTOMER,
        S.ADDRESS,
        S.COMPLEMENT,
        S.NEIGHBORHOOD,
        S.ZIPCODE,
        S.TAXID,
        S.STATUS,
        S.CITY,
        S.STATE,
        S.COUNTRY,
        S.MARKET,
        S.TERRITORY,
        S.SEGMENTATION,
        S.CUSTOMERGROUP,
        S.CREDITBLOCKED,
        S.ALLCUSTOMER,
        S.CMM_CRUSH_CIDADEDESTINO,
        S.CUSTOMER_CITY,
        S.CUSTOMER_DISPLAYNAME,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_customermaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_customermaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_customermaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}