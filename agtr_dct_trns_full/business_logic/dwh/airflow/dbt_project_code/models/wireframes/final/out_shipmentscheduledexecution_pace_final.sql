-- noqa: disable=all
{% set keys = [
    'version_name', 'item', 'transshipment', 'location', 'operationtype',
    'supplierid', 'source', 'transmode', 'carrier', 'customer', 'day'
    ]
%}

{%
    set another_columns = [
     'planned', 'oc_delayed', 'oc_emit', 'loading_order', 'checkin', 'invoice'
    ]
%}

{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete_rearch('out_shipmentscheduledexecution_pace', ref('out_shipmentscheduledexecution_pace'), " ~ keys ~ ", " ~ another_columns ~ ") }}",
    "{{ check_dbt_run_log('out_shipmentscheduledexecution_pace') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf06'],
        post_hook = list_post_hooks
    )
}}

WITH
FINAL AS (
    SELECT
        S.VERSION_NAME,
        S.ITEM,
        S.TRANSSHIPMENT,
        S.LOCATION,
        S.OPERATIONTYPE,
        S.SUPPLIERID,
        S.SOURCE,
        S.TRANSMODE,
        S.CARRIER,
        S.CUSTOMER,
        S.DAY,
        S.PLANNED,
        S.OC_DELAYED,
        S.OC_EMIT,
        S.LOADING_ORDER,
        S.CHECKIN,
        S.INVOICE,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_shipmentscheduledexecution_pace', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_shipmentscheduledexecution_pace') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}

)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_shipmentscheduledexecution_pace') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}