{% macro order_statuses() %}
    {{ log('listing the order statuses') }}
    {{ return(['placed', 'shipped']) }}
{% endmacro %}
