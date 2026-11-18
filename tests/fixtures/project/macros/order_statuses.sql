{% macro order_statuses() %}
    {{ log('listing the order statuses') }}
    {{ exceptions.warn('order statuses are hard-coded') }}
    {{ return(['placed', 'shipped']) }}
{% endmacro %}
