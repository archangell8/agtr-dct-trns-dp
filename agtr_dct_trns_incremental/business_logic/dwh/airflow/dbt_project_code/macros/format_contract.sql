{% macro format_contract(contract_field) %}
    CASE
        WHEN LPAD({{ contract_field }}, 11, '0') = '00000000000' 
            THEN NULL
        /* SE TERMINAR COM CARACTERE ALFABETICO, DEVERA POSSUIR 11 CARACTERES COM ZERO A ESQUERDA */ -- noqa
        WHEN REGEXP_LIKE({{ contract_field }}, '.*[A-Za-z]$')
            THEN LPAD({{ contract_field }}, 11, '0')
        /* SE NÃO, DEVERÁ POSSUIR 10CARACTERES COM ZERO A ESQUERDA */
        ELSE LPAD({{ contract_field }}, 10, '0')
    END
{% endmacro %}
