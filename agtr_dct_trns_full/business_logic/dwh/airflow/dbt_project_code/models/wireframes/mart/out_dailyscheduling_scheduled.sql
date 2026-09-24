-- noqa: disable=RF06

-- This model has a particular logic, once only have inserts,
-- updates and deletes should not be performed. For this reason, the table
-- trf_contract_control was created, where the PK is CONTRACT_LINEID and SOURCE,
-- once this combination is inserted on the control table, it will not be
-- inserted again on the DailyScheduling model, even if the key is
-- reprocessed by intstg_createtrfcontracts.

{% set post_hook = [
    """
    INSERT INTO {{ this.database }}.{{ this.schema }}.trf_contracts_control
    SELECT DISTINCT
        CONTRACT_LINEID,
        SOURCE,
        CURRENT_DATE() AS CREATION_DATE
    FROM {{ this }} AS A
    WHERE NOT EXISTS (
        SELECT 1
        FROM {{ ref('trf_contracts_control') }} AS CONTROL
        WHERE
            CONTROL.CONTRACT_LINEID = A.CONTRACT_LINEID
            AND CONTROL.SOURCE = A.SOURCE
    )
    """
] %}

{{
    config(
        materialized='incremental',
        tags=['wf38a'],
        post_hook=post_hook
    )
}}

WITH
DAILY_SCHED AS (
    SELECT
        'CurrentWorkingView' AS VERSION_NAME,
        TRF.CONTRACTLINEID AS CONTRACT_LINEID,
        TRF.ITEM,
        TRF.SUPPLIER AS SUPPLIER_LOCATION,
        TRF.TRANSMODE,
        TRF.PICKUP AS SOURCE,
        'TRF' AS OPERATION_TYPE,
        'N/A' AS "LOCATION",
        'N/A' AS SURVEYOR,
        'N/A' AS CUSTOMER,
        0 AS SCHEDULEDQTY,
        TO_CHAR(DAY, 'DD-MON-YY') AS "DAY"
    FROM {{ ref('intstg_createtrfcontracts') }} AS TRF
    -- Only appends to the table if its a new contractlineid
    LEFT JOIN {{ ref('trf_contracts_control') }} AS TRF_CONTROL
        ON
            TRF.CONTRACTLINEID = TRF_CONTROL.CONTRACT_LINEID
            AND TRF.PICKUP = TRF_CONTROL.SOURCE
    WHERE
        1 = 1
        AND TRF_CONTROL.CONTRACT_LINEID IS NULL
)

SELECT
    *,
    HASH(*) AS HASH_ID
FROM DAILY_SCHED
