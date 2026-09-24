-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'id', 'itemid'
] %}
{% set list_another_columns = [
    'contractnumber', 'supplierid', 'source', 'farm', 'destination',
    'delivery', 'deliveryunitid', 'origination', 'transmode',
    'freighttype', 'deliverystart', 'deliveryend', 'status',
    'fiscalcondition', 'type', 'paymentdate', 'paymentdetails',
    'salesrep', 'freightcost', 'actualcost', 'freightcadence', 'plannedcost',
    'currency', 'quantity', 'receivedquantity', 'receivedpaf', 'toreceivetotal',
    'toreceiveflat', 'toreceivepaf', 'cancelledquantity', 'uom', 'price',
    'globalinvoice', 'harvest', 'priority', 'purchasedate',
    'isslipwithchangeddestination', 'contractnumber_internal'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_execution'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

{% set list_post_hooks = [] %}

-- Check if the post_hook should be execute
{% if check_model_group_scheduler(list_tags, 'SourcingContractDetails') %}
    {% do list_post_hooks.append(
        "{{ get_cdp_transaction_delete(ref('sourcing_contract_details_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}"
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
SOURCING_CONTRACT_DETAILS AS (
    SELECT
        S.ID,
        S.CONTRACTNUMBER,
        S.SUPPLIERID,
        S.SOURCE,
        S.DESTINATION,
        S.DELIVERY,
        S.DELIVERYUNITID,
        S.ORIGINATION,
        S.TRANSMODE,
        S.FREIGHTTYPE,
        S.DELIVERYSTART,
        S.DELIVERYEND,
        S.STATUS,
        S.SALESREP,
        S.FISCALCONDITION,
        S.TYPE,
        S.PAYMENTDATE,
        S.PAYMENTDETAILS,
        S.FARM,
        S.HARVEST,
        S.ITEMID,
        S.FREIGHTCOST,
        S.ACTUALCOST,
        S.FREIGHTCADENCE,
        S.PLANNEDCOST,
        S.CURRENCY,
        S.QUANTITY,
        S.RECEIVEDQUANTITY,
        S.RECEIVEDPAF,
        S.TORECEIVETOTAL,
        S.TORECEIVEFLAT,
        S.TORECEIVEPAF,
        S.CANCELLEDQUANTITY,
        S.UOM,
        S.PRICE,
        S.GLOBALINVOICE,
        S.PRIORITY,
        S.PURCHASEDATE,
        S.ISSLIPWITHCHANGEDDESTINATION,
        S.CONTRACTNUMBER_INTERNAL,
        S.HASH_ID, -- noqa
        {{ get_cdp_transaction('S', 'HASH_ID', list_keys) }} -- noqa
    FROM {{ ref('sourcing_contract_details_master') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='SourcingContractDetails') }}
FROM SOURCING_CONTRACT_DETAILS

{% if check_model_group_scheduler(list_tags, 'SourcingContractDetails') %}
    WHERE 1 = 1
{% else %}
    WHERE 1 = 0
{% endif %}
