-- noqa: disable=all
{% set keys = [
    'version_name', 'location', 'item', 'day', 'company'
    ]
%}

{%
    set another_columns = [
    'oh_quantity_plants'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_onhandsplants', ref('out_onhandsplants'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_onhandsplants') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf41b'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.LOCATION,
        S.ITEM,
        S.DAY,
        S.COMPANY,
        S.OH_QUANTITY_PLANTS,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_onhandsplants', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_onhandsplants') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_onhandsplants') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}