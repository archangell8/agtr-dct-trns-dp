-- noqa: disable=all

-- Define constants
{% set list_keys = [
    'portwindowid'
] %}
{% set list_another_columns = [
    'location', 'startcak', 'endcak', 'startrolling', 'endrolling',
    'portwindowstatus', 'quantity', 'uom'
] %}
{% set list_tags = [
    'model_mart', 'delta_full', 'delta_vessel'
] %}

{% set list_pre_hooks = [
    "{{ update_control_unload_ts(this, 'pre_hook') }}"
] %}

--update_control_unload_ts has to be the last post_hook
{% set list_post_hooks = [
    "{{ get_cdp_transaction_delete(ref('port_window_master'), " ~ list_keys ~ ", " ~ list_another_columns ~ ") }}",
    "{{ update_control_unload_ts(this, 'post_hook') }}"
] %}

{{
    config(
        materialized = 'table',
        unique_key = list_keys,
        tags = list_tags,
        pre_hook = list_pre_hooks,
        post_hook = list_post_hooks
    )
}}

WITH
PORT_WINDOW AS (
    SELECT
        V.PORTWINDOWID,
        V.LOCATION,
        V.STARTCAK,
        V.ENDCAK,
        V.STARTROLLING,
        V.ENDROLLING,
        V.PORTWINDOWSTATUS,
        V.QUANTITY,
        V.UOM,
        V.HASH_ID,
        {{ get_cdp_transaction('V', 'HASH_ID', list_keys) }}
    FROM {{ ref('port_window_master') }} AS V
    /* If incemental apply macro */
    {{ set_incremental_strategy('V', 'HASH_ID', list_keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='PortWindow') }}
FROM PORT_WINDOW
