{{ config(materialized='table') }}
{# orders below the threshold are left out in dev #}
{% set threshold = 1 %}

with source_orders as (
    select order_id, status
    from {{ ref('stg_orders') }}
    {% if target.name == 'dev' %}
    where order_id >= {{ threshold }}
    {% endif %}
)

select
    order_id,
    upper(status) as status
from source_orders
