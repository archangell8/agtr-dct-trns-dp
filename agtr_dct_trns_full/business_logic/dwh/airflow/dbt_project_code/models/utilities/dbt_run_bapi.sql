-- noqa:disable=RF06
{{
    config(
        materialized='incremental',
        pre_hook=[
            """
            CREATE SEQUENCE IF NOT EXISTS {{ target.database }}.{{ target.schema }}.SEQ_ID_DBTRUNBAPI
            START = 1 INCREMENT = 1
        """
        ],
        post_hook=[
            """
            CREATE TABLE IF NOT EXISTS {{ target.database }}.{{ target.schema }}.DYNAMIC_SCHEDULED_CALLS(
                ENTITY_NAME VARCHAR(100) NOT NULL,
                FIELDS VARIANT NOT NULL,
                URL VARCHAR(2048) NOT NULL,
                VERSION NUMBER(38,0) NOT NULL,
                SCHEDULE VARCHAR(100) NOT NULL DEFAULT '0 */15 8-23,0 * * *',
                CREATED_AT TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
                DELETED_AT TIMESTAMP_NTZ NULL,
                CREATED_USER_ID VARCHAR(10) NOT NULL,
                DELETED_USER_ID VARCHAR(10) NULL
            )
        """
        ]
    )
}}

-- Post hook creates a table to be used exclusively by API
-- Only for create the table if not exists
SELECT DISTINCT
    NULL AS ID,
    NULL AS APPLICATION_NAME,
    NULL AS LAST_BAPI_EXECUTION
WHERE 1 = 0
