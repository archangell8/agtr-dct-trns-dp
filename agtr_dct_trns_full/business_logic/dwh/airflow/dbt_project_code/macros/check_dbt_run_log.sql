--noqa:disable=all
{% macro check_dbt_run_log(application_name) %}
    INSERT INTO {{ ref('dbt_run_bapi') }}
        SELECT
            {{ target.database }}.{{ target.schema }}.SEQ_ID_DBTRUNBAPI.NEXTVAL AS ID,
            UPPER('{{ application_name }}') AS APPLICATION_NAME,
            TO_CHAR(
                CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP),
                'YYYY-MM-DD HH24:MI:SS'
            ) AS LAST_BAPI_EXECUTION
        WHERE
            IFF(
                (SELECT 1 FROM {{ ref('dbt_run_bapi') }} WHERE APPLICATION_NAME = UPPER('{{ application_name }}')) is not null,
                1 = 0,
                1 = 1
            )
{% endmacro %}