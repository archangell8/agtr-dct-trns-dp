-- noqa: disable=all
{% set keys = [
    'version_name', 'demandid', 'contract_lineid'
    ]
%}

{%
    set another_columns = [
        'so_bp_association'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_spbpassociation', ref('out_spbpassociation'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_spbpassociation') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf_sobpassociation'],
        post_hook = list_post_hooks
    )
}}

WITH FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.DEMANDID,
        S.CONTRACT_LINEID,
        S.SO_BP_ASSOCIATION,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_spbpassociation', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_spbpassociation') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_spbpassociation') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}