-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'supplierid'
] %}
{% set list_another_columns = [
    'taxid', 'name', 'status', 'address', 'complement', 'neighborhood',
    'zipcode', 'city', 'state', 'country', 'market', 'territory',
    'segmentation', 'suppliergroup', 'suppliergroupdescription',
    'creditblocked'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'Supplier') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('supplier_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
    ) %}
{% endif %}

--update_control_unload_ts has to be the last post_hook
{% do list_post_hooks.append(
    "{{ update_control_unload_ts(this, 'post_hook') }}"
) %}


{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = list_keys,
        tags = list_tags,
        pre_hook = list_pre_hooks,
        post_hook = list_post_hooks
    )
}}

WITH
SUPPLIER AS (
    SELECT
        S.SUPPLIERID,
        S.TAXID,
        S.NAME,
        S.STATUS,
        S.ADDRESS,
        S.COMPLEMENT,
        S.NEIGHBORHOOD,
        S.ZIPCODE,
        S.CITY,
        S.STATE,
        S.COUNTRY,
        S.MARKET,
        S.TERRITORY,
        S.SEGMENTATION,
        S.SUPPLIERGROUP,
        S.SUPPLIERGROUPDESCRIPTION,
        S.CREDITBLOCKED,
        S.HASH_ID,
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }}
    FROM {{ ref('supplier_master') }} AS S

    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='Supplier') }}
FROM SUPPLIER

{% if check_model_group_scheduler(list_tags, 'Supplier') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
