{{
    config(
        materialized='incremental',
        pre_hook=[
            """
            CREATE SEQUENCE IF NOT EXISTS {{ target.database }}.{{ target.schema }}.SEQ_ID_SHIPMENT 
            START = 1 INCREMENT = 1
        """
        ]
    )
}}

SELECT
    NULL AS BK,
    NULL AS ID
WHERE 1 = 0
-- This model was created only to create the empty table if it does not exists.
