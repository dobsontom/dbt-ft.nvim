{% macro grant_select(role) %}
    {% if target.name == 'prod' %}
        grant select on {{ this }} to role {{ role }}
    {% else %}
        select 1
    {% endif %}
{% endmacro %}
