-- noqa: disable=all
{% macro update_timestamp_inc_old_shipments(model_name, num_months) %}
    {% set date_condition = """
        (
            ACTUALSHIPDATE != 'N/A'
            AND TO_TIMESTAMP(
                ACTUALSHIPDATE, 'DD-MM-YYYY HH24:MI:SS'
            ) <= DATEADD(MONTH, -""" ~ num_months ~ """, CURRENT_TIMESTAMP)
        )
        OR
        (
            ESTIMATEDSHIPDATE != 'N/A'
            AND TO_TIMESTAMP(
                ESTIMATEDSHIPDATE, 'DD-MM-YYYY'
            ) <= DATEADD(MONTH, -""" ~ num_months ~ """, CURRENT_DATE)
        )
    """ %}

    {% if model_name == 'shipment_details' %}
        UPDATE {{ this }}
        SET CDP_TIMESTAMP_INC = '1900-01-01 00:00:00'
        WHERE
            1 = 1
            AND CDP_TIMESTAMP_INC IS NOT NULL
            AND ({{ date_condition }})

    {% elif model_name == 'shipment_status_quality_details' %}
        UPDATE {{ this }} AS F
        SET CDP_TIMESTAMP_INC = '1900-01-01 00:00:00'
        FROM (
            SELECT * FROM {{ ref('shipment_details') }}
            WHERE
                1 = 1
                AND ({{ date_condition }})
        ) AS T
            WHERE
                1 = 1
                AND F.SHIPMENTID = T.ID
                AND T.CDP_TIMESTAMP_INC IS NOT NULL


    {% elif model_name == 'shipment_penalties' %}
        UPDATE {{ this }} AS F
        SET CDP_TIMESTAMP_INC = '1900-01-01 00:00:00'
        FROM (
            SELECT * FROM {{ ref('shipment_details') }}
            WHERE
                1 = 1
                AND ({{ date_condition }})
        ) AS T
            WHERE
                1 = 1
                AND F.SHIPMENTID = T.ID
                AND T.CDP_TIMESTAMP_INC IS NOT NULL

    {% else %}
        RAISE 'Modelo não suportado: ' || model_name;
    {% endif %}
{% endmacro %}
