-- noqa: disable=all
{% macro filter_remove_jde_delete_data(alias_table) %}
    (COALESCE({{ alias_table }}.OP_TYPE, '-') NOT IN ('0', '3') OR ({{ alias_table }}.OP_TYPE = '0' AND {{ alias_table }}.OP_TIME = 0))
{% endmacro %}
