select
    order_id,
    {% for method in ['card', 'voucher'] %}
    sum(case when method = '{{ method }}' then amount end) as {{ method }}_amount
    {%- if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('order_payments') }}
group by order_id
