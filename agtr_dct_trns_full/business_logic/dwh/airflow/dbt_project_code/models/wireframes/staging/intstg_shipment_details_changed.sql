-- noqa: disable=all
{{
    config(
        materialized='table',
        tags=['wf38a_recflag']
    )
}}

/* The purpose of this model is to identify shipmentlineids that was updated
or inserted to be consumed by recalculate flags logics */

WITH
INTSTG_SHIPMENT_DETAILS_TEMP AS (
    /* If the model doesn't exists, use the source table */
    {% set exists_table = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.table) %}
    {% if not exists_table %}
        SELECT DISTINCT *
        FROM {{ ref('intstg_shipment_details') }}

    /* If the table exists, reference itself */
    {% else %}
        SELECT DISTINCT *
        FROM {{ this }}

    {% endif %}
)

SELECT
    A.*,
    CASE
        WHEN A.SHIP_HASH_ID != B.SHIP_HASH_ID OR B.SHIP_HASH_ID IS NULL
            THEN 1
        ELSE 0
    END AS CHANGED_FLAG
FROM {{ ref('intstg_shipment_details') }} AS A
LEFT JOIN INTSTG_SHIPMENT_DETAILS_TEMP AS B
    ON
        A.ID = B.ID
        AND A.ITEM = B.ITEM
        AND A.SHIPMENTLINEID = B.SHIPMENTLINEID
