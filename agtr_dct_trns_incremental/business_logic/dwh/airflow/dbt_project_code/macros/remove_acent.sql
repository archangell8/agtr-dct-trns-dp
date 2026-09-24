{% macro remove_acent(column_name) %}
TRANSLATE(
    REPLACE(
        REGEXP_REPLACE(
            {{ column_name }},
            '[-:|.°º\_]',
            ' '
        ), '  ', ' '
    ),
    'ÁÉÍÓÚÂÊÎÔÛáéíóúâêîôûàèìòùÇãçÃ',
    'AEIOUAEIOUaeiouaeiouaeiouCacA'
)
{% endmacro %}
