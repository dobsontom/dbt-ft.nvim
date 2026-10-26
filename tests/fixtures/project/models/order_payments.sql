select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'method']) }} as payment_key,
    amount
from {{ ref('orders') }}
