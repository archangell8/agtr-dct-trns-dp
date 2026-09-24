-- noqa: disable=all
{% macro regex_find_contract_pttn_2(column_name, all_contract_valid_words, occurrence) %}
    -- REGEX PRA BUSCA DO CONTRATO, SEGUNDO POSSIVEL PADRAO (MAIS FLEXIVEL QUE O PRIMEIRO)
	COALESCE(
        -- BUSCA O NUMERO DO CONTRATO APOS OS TERMOS CITADOS */
        REGEXP_SUBSTR(
                {{ column_name }},
            '\\b({{ all_contract_valid_words }})[ :\\.-]?(\\d{8,10}[A-Z]?)',
            1, {{ occurrence }}, 'e', 2
        ),
        -- BUSCA O PADRAO DO NÚMERO DE CONTRATO EM QUALQUER PARTE DO TEXTO
        REGEXP_SUBSTR(
            {{ column_name }},
            '\\b\\d{8,10}[A-Z]?\\b',
            1, {{ occurrence }}, 'e'
        )
    )
{% endmacro %}
