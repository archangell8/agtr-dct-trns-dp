-- noqa: disable=all
{% set keys = [
    'contractid', 'recalculate_actuals_flag'
    ]
%}

{%
    set another_columns = []
%}

{% set list_post_hooks = [
    "{{ check_dbt_run_log('out_dimcontractactualsflag') }}"

] %}

{{
    config(
        materialized = var('mat'),
        incremental_strategy = var('mat_inc_strat'),
        unique_key = keys,
        tags=['wf38a_recflag'],
        post_hook = list_post_hooks
    )
}}

WITH FINAL AS (
    SELECT
        S.CONTRACTID,
        S.RECALCULATE_ACTUALS_FLAG,
        S.HASH_ID,
        {% if is_incremental() %}
            CASE
                WHEN T.CONTRACTID IS NOT NULL THEN 'U'
                ELSE 'I'
            END AS CDP_TRANSACTION
        {% else %}
            'I' AS CDP_TRANSACTION
        {% endif %}
    FROM {{ ref('out_dimcontractactualsflag') }} AS S
    /* If incemental apply macro */
    {% if is_incremental() %}
        LEFT JOIN {{ this }} AS T
            ON
                S.CONTRACTID = T.CONTRACTID
    {% endif %}
)

SELECT
    *,
    {{ get_cdp_timestamp(filename_o9='out_dimcontractactualsflag') }}
FROM FINAL

-- {% if is_incremental() %}
--     WHERE 1 = 1
-- {% else %}
--     WHERE 1 = 0
-- {% endif %}