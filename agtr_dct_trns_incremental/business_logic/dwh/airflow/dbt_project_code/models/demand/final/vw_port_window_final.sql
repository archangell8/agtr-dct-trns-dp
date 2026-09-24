-- noqa: disable=all
{% set list_tags = ['model_final', 'delta_full', 'delta_vessel'] %}

{{
    config(
        materialized = 'view',
        tags = list_tags
    )
}}

WITH FINAL AS (
    SELECT
        0 AS IDX,
        'PORTWINDOWID' AS PORTWINDOWID,
        'LOCATION' AS LOCATION, -- noqa
        'STARTCAK' AS STARTCAK,
        'ENDCAK' AS ENDCAK,
        'STARTROLLING' AS STARTROLLING,
        'ENDROLLING' AS ENDROLLING,
        'PORTWINDOWSTATUS' AS PORTWINDOWSTATUS,
        'QUANTITY' AS QUANTITY,
        'UOM' AS UOM,
        NULL AS HASH_ID,
        NULL AS CDP_TRANSACTION,
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('port_window')) AS CDP_TIMESTAMP_FULL, -- noqa
        (SELECT CDP_TIMESTAMP FROM {{ ref('tab_cdp_timestamp_models') }} WHERE MODEL_NAME = UPPER('port_window')) AS CDP_TIMESTAMP_INC, -- noqa
        'CDP_TIMESTAMP_O9' AS CDP_TIMESTAMP_O9

    UNION ALL

    SELECT
        1 AS IDX,
        PORTWINDOWID::STRING,
        LOCATION::STRING,
        STARTCAK::STRING,
        ENDCAK::STRING,
        STARTROLLING::STRING,
        ENDROLLING::STRING,
        PORTWINDOWSTATUS::STRING,
        QUANTITY::STRING,
        UOM::STRING,
        HASH_ID,
        CDP_TRANSACTION,
        CDP_TIMESTAMP_FULL,
        CDP_TIMESTAMP_INC,
        CDP_TIMESTAMP_O9::STRING
    FROM {{ ref('port_window') }}
    {% if check_model_group_scheduler(list_tags, 'PortWindow') %}
        WHERE 1 = 1
    {% else %}
        WHERE 1 = 0
    {% endif %}
)

SELECT
    PORTWINDOWID,
    LOCATION,
    STARTCAK,
    ENDCAK,
    STARTROLLING,
    ENDROLLING,
    PORTWINDOWSTATUS,
    QUANTITY,
    UOM,
    HASH_ID,
    CDP_TRANSACTION,
    CDP_TIMESTAMP_FULL,
    CDP_TIMESTAMP_INC,
    CDP_TIMESTAMP_O9
FROM FINAL
ORDER BY IDX ASC
