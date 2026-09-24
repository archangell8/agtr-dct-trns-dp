-- noqa: disable=all

-- This macro is responsable to update tab_airflow_unload_control table
-- to be used by astro/airflow as file unload timestamp reference.

{% macro update_control_unload_ts(model, type_hook) %}
-- depends_on: {{ ref('tab_airflow_unload_control') }}

    {% if execute %}
        {% set model_name = 'vw_'~ model.table ~ '_final' %}

        {% do log(
            'Log: Model ' ~ model_name ~ ' executing ' ~ type_hook
        ) %}

        {% if type_hook == 'pre_hook' %}
            -- Check if model exists on tab_airflow_unload_control
            {% set model_exists_query %}
                SELECT COUNT(*) FROM {{ ref('tab_airflow_unload_control') }} WHERE MODEL = '{{ model_name | upper }}'
            {% endset %}
            {% set var_model_exists = run_query(model_exists_query).columns[0].values()[0] %}

            {% if var_model_exists == 0 %}
                -- If model doesn't exists, insert on control table
                {% do log(
                    'Log: Model ' ~ model_name ~ ' - Does not exists on control table, inseting on.'
                ) %}

                INSERT INTO {{ ref('tab_airflow_unload_control') }}
                (MODEL, LAST_EXECUTION, CURRENT_EXECUTION)
                VALUES ('{{ model_name | upper }}', NULL, NULL);

            {% else %}
                {% do log(
                    'Log: Model ' ~ model_name ~ ' - Already exists on control table.'
                ) %}
            {% endif %}

            -- Retrieve last_execution timestamp
            {% set last_execution_query %}
                SELECT LAST_EXECUTION FROM {{ ref('tab_airflow_unload_control') }} WHERE MODEL = '{{ model_name | upper }}'
            {% endset %}
            {% set var_last_execution = run_query(last_execution_query).columns[0].values()[0] %}
            {% do log(
                'Log: Model ' ~ model_name ~ ' - Retrievered LAST_EXECUTION as ' ~ var_last_execution
            ) %}

            -- Retrieve current_execution timestamp
            {% set current_execution_query %}
                SELECT CURRENT_EXECUTION FROM {{ ref('tab_airflow_unload_control') }} WHERE MODEL = '{{ model_name | upper }}'
            {% endset %}
            {% set var_current_execution = run_query(current_execution_query).columns[0].values()[0] %}
            {% do log(
                'Log: Model ' ~ model_name ~ ' - Retrievered CURRENT_EXECUTION as ' ~ var_current_execution
            ) %}
            -- In post hook only last_execution is updated with previous current_execution timestamp
            -- to prevent losing reference if query or some post hook fails and need to be re-executed
            {% if not var_current_execution %}
                -- If current_execution is null, last_execution can't be updated with this value
                -- so will be updated to biggest cdp_timestamp between cdp_timestamp_full and cdp_timestamp_inc

                -- Retrieve max of cdp_timestamp of current model
                {% set last_execution_query %}
                    SELECT GREATEST(MAX(COALESCE(CDP_TIMESTAMP_FULL, '0')), MAX(COALESCE(CDP_TIMESTAMP_INC, '0'))) FROM {{ this }}
                {% endset %}
                {% set var_last_execution = run_query(last_execution_query).columns[0].values()[0] %}
                {% do log(
                    'Log: Model ' ~ model_name ~ ' - Retrievered MAX of CDP_TIMESTAMP as ' ~ var_last_execution
                ) %}

                UPDATE
                    {{ ref('tab_airflow_unload_control') }} AS T
                SET
                    T.LAST_EXECUTION = '{{ var_last_execution }}'
                WHERE
                T.MODEL = '{{ model_name | upper }}';

            {% else %}
                -- Set last_execution with current_execution timestamp
                UPDATE
                    {{ ref('tab_airflow_unload_control') }} AS T
                SET
                    T.LAST_EXECUTION = '{{ var_current_execution }}'
                WHERE
                T.MODEL = '{{ model_name | upper }}';
            {% endif %}
        {% elif type_hook == 'post_hook' %}
            -- Update current_execution to current timestamp
            {% set current_timestamp_query %}
                SELECT TO_CHAR(
                    CONVERT_TIMEZONE('UTC', CURRENT_TIMESTAMP()),
                    'YYYY-MM-DD HH24:MI:SS'
                )
            {% endset %}
            {% set var_current_timestamp = run_query(current_timestamp_query).columns[0].values()[0] %}
            {% do log(
                'Log: Model ' ~ model_name ~ ' - Retrievered current timestamp as ' ~ var_current_timestamp
            ) %}
            UPDATE
                {{ ref('tab_airflow_unload_control') }} AS T
            SET
                T.CURRENT_EXECUTION = '{{ var_current_timestamp }}'
            WHERE
                T.MODEL = '{{ model_name | upper }}';
        {% else %}
            {% do log(
                'Variable "type_hook" has no valid value, should be "pre_hook" or "post_hook".'
            ) %}
        {% endif %}
    {% else %}
        SELECT 1
    {% endif %}

{% endmacro %}
