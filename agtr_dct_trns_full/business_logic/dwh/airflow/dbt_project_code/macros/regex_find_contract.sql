-- noqa: disable=all
{% macro regex_find_contract(column_name, search_keywords, occurrence, pattern=1) %}
    {% if pattern == 1 %}
        COALESCE(
            -- Busca o número do contrato após os termos citados, permitindo que o número não termine com um limite de palavra
            -- Exemplo: Se search_keywords for "CONTRATO", e column_name tiver o valor "CONTRATO: 12345678A",
            -- a expressão regular '\\b(CONTRATO)[ :\\.-]?(\\d{8,10}[A-Z]?)' encontrará "12345678A".
            REGEXP_SUBSTR(
                {{ column_name }},
                '\\b({{ search_keywords }})[ :\\.-]?(\\d{8,10}[A-Z]?)',
                1, {{ occurrence }}, 'e', 2
            ),
            -- Busca o padrão do número de contrato em qualquer parte do texto
            -- Exemplo: Se column_name tiver o valor "Número do contrato é 12345678A",
            -- a expressão regular '\\b\\d{8,10}[A-Z]?\\b' encontrará "12345678A".
            REGEXP_SUBSTR(
                {{ column_name }},
                '\\b\\d{9,10}[A-Z]?\\b',
                1, {{ occurrence }}, 'e'
            )
        )
    {% elif pattern == 2 %}
        COALESCE(
            -- Busca o número do contrato após os termos citados, exigindo que o número termine com um limite de palavra
            -- Exemplo: Se search_keywords for "CONTRATO", e column_name tiver o valor "CONTRATO: 12345678A",
            -- a expressão regular '\\b(CONTRATO)[ :\\.-]?(\\d{8,10}[A-Z]?)\\b' encontrará "12345678A".
            -- Note que o número do contrato deve terminar com um limite de palavra (\\b).
            REGEXP_SUBSTR(
                {{ column_name }},
                '\\b({{ search_keywords }})[ :\\.-]?(\\d{8,10}[A-Z]?)\\b',
                1, {{ occurrence }}, 'e', 2
            ),
            -- Busca o padrão do número de contrato em qualquer parte do texto
            -- Exemplo: Se column_name tiver o valor "Número do contrato é 12345678A",
            -- a expressão regular '\\b\\d{8,10}[A-Z]?\\b' encontrará "12345678A".
            REGEXP_SUBSTR(
                {{ column_name }},
                '\\b\\d{8,10}[A-Z]?\\b',
                1, {{ occurrence }}, 'e'
            )
        )
    {% endif %}
{% endmacro %}