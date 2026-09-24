-- noqa: disable=all
{% set keys = [
    'demandid'
    ]
%}

{%
    set another_columns = [
        'all_demand', 'demand_group', 'demand_headerid', 'demand_requestid',
        'demandid_displayname', 'charter', 'buyer', 'destination', 'vessel',
        'source_bp', 'freight_type', 'committed_date', 'available_qty', 'ship_to',
        'ownership', 'status', 'blocking_type', 'operation_type', 'freight_terms',
        'demand_shipto', 'smac_branch_plant', 'smac_origem_cidade_uf',
        'smac_cliente_nome', 'smac_destino_cidade_uf', 'smac_produto',
        'cmm_crush_ibgecode', 'cmm_crush_subregion', 'demand_status',
        'reference_port', 'delivered_qty', 'shipto_subregion', 'cmm_shipto_address',
        'laycan_min', 'laycan_max', 'eta', 'etb', 'etc', 'penalty_etc',
        'demurrage_rate', 'despatch_rate', 'quantity', 'shipto_displayname',
        'shipto_location_type', 'pickup_location'

    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_demandmaster') }}"
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
        S.ALL_DEMAND,
        S.DEMAND_GROUP,
        S.DEMAND_HEADERID,
        S.DEMAND_REQUESTID,
        S.DEMANDID,
        S.DEMANDID_DISPLAYNAME,
        S.SHIPTO_DISPLAYNAME,
        S.CHARTER,
        S.BUYER,
        S.DESTINATION,
        S.VESSEL,
        S.SOURCE_BP,
        S.FREIGHT_TYPE,
        S.COMMITTED_DATE,
        S.AVAILABLE_QTY,
        S.SHIP_TO,
        S.OWNERSHIP,
        S.STATUS,
        S.BLOCKING_TYPE,
        S.OPERATION_TYPE,
        S.FREIGHT_TERMS,
        S.DEMAND_SHIPTO,
        S.SMAC_BRANCH_PLANT,
        S.SMAC_ORIGEM_CIDADE_UF,
        S.SMAC_CLIENTE_NOME,
        S.SMAC_DESTINO_CIDADE_UF,
        S.SMAC_PRODUTO,
        S.CMM_CRUSH_IBGECODE,
        S.CMM_CRUSH_SUBREGION,
        S.DEMAND_STATUS,
        S.REFERENCE_PORT,
        S.DELIVERED_QTY,
        S.SHIPTO_SUBREGION,
        S.SHIPTO_LOCATION_TYPE,
        S.CMM_SHIPTO_ADDRESS,
        S.LAYCAN_MIN,
        S.LAYCAN_MAX,
        S.ETA,
        S.ETB,
        S.ETC,
        S.PENALTY_ETC,
        S.DEMURRAGE_RATE,
        S.DESPATCH_RATE,
        S.QUANTITY,
        S.PICKUP_LOCATION,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_demandmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_demandmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_demandmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}
