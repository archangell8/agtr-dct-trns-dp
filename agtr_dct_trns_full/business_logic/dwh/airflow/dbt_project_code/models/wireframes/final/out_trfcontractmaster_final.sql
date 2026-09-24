-- noqa: disable=all
{% set keys = [
    'contractid', 'contractlineid', 'id', 'pickup'
    ]
%}

{%
    set another_columns = [
        'destination, item, transmode, all_contract, contract_type,
        contract_status, start_date, end_date, status, freight_type, farm,
        fiscal_condition, type, producer, scheduling_status, quantity,
        purchased, lastdateofscheduledgenerated'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_trfcontractmaster') }}"
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
        S.CONTRACTID,
        S.CONTRACTLINEID,
        S.ID,
        S.DESTINATION,
        S.ITEM,
        S.PICKUP,
        S.TRANSMODE,
        S.ALL_CONTRACT,
        S.CONTRACT_TYPE,
        S.CONTRACT_STATUS,
        S.START_DATE,
        S.END_DATE,
        S.STATUS,
        S.FREIGHT_TYPE,
        S.FARM,
        S.FISCAL_CONDITION,
        S.TYPE,
        S.PRODUCER,
        S.SCHEDULING_STATUS,
        S.QUANTITY,
        S.PURCHASED,
        S.LASTDATEOFSCHEDULEDGENERATED,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_trfcontractmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_trfcontractmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_trfcontractmaster') }}
FROM FINAL
