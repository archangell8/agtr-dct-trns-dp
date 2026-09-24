-- noqa: disable=all
{% set keys = [
    'item'
    ]
%}

{%
    set another_columns = [
        'item_base_uom', 'resource', 'package_size', 'item_status',
        'item_class', 'item_stage', 'item_type', 'l1', 'l2', 'l3', 'l4', 'l5',
        'l6', 'planning_item', 'reporting_item', 'segmentation_category',
        'all_item', 'fnitem', 'rgm11', 'rgm12', 'rgm13', 'rgm14', 'rgm15',
        'rgm16', 'rgm17', 'rgm18', 'rgm19', 'rgm20', 'stat_item_group',
        'item_displayname', 'memberdisplaycolor', 'crop_date'
    ]
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_itemmaster') }}"
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
        S.ITEM,
        S.ITEM_BASE_UOM,
        S.RESOURCE,
        S.PACKAGE_SIZE,
        S.ITEM_STATUS,
        S.ITEM_CLASS,
        S.ITEM_STAGE,
        S.ITEM_TYPE,
        S.L1,
        S.L2,
        S.L3,
        S.L4,
        S.L5,
        S.L6,
        S.PLANNING_ITEM,
        S.REPORTING_ITEM,
        S.SEGMENTATION_CATEGORY,
        S.ALL_ITEM,
        S.ITEM_DISPLAYNAME,
        S.MEMBERDISPLAYCOLOR,
        S.CROP_DATE,
        S.HASH_ID,
        {{ get_cdp_transaction_rearch('out_itemmaster', 'S', 'HASH_ID', keys) }}
    FROM {{ ref('out_itemmaster') }} AS S
    /* If incemental apply macro */
    {{ set_incremental_strategy('S', 'HASH_ID', keys) }}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_itemmaster') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}