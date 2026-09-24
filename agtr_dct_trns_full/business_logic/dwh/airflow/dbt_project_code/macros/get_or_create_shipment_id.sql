{% macro get_or_create_shipment_id(bk) %}
    {% set existing_id_query %}
        -- Query to check if the bk already exists in the tab_shipment_control_id table
        SELECT id FROM {{ ref('tab_shipment_control_id') }} WHERE bk = '{{ bk }}'
    {% endset %}

    {% set existing_id = run_query(existing_id_query).columns[0].values() %}

    {% if existing_id %}
        -- If the bk exists, return the existing id
        {{ existing_id[0] }}
    {% else %}
        {% set insert_query %}
            -- Insert the new bk into the tab_shipment_control_id table
            INSERT INTO {{ ref('tab_shipment_control_id') }} (bk) VALUES ('{{ bk }}')
        {% endset %}

        {{ run_query(insert_query) }}

        {% set new_id_query %}
            -- Query to retrieve the newly inserted id for the bk
            SELECT id FROM {{ ref('tab_shipment_control_id') }} WHERE bk = '{{ bk }}'
        {% endset %}

        {% set new_id = run_query(new_id_query).columns[0].values() %}

        -- Return the newly inserted id
        {{ new_id[0] }}
    {% endif %}
{% endmacro %}
