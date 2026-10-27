select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'method']) }} as payment_key,
    amount as amount_{{ dbt_utils.slugify('GBP') }}
from {{ ref('orders') }}
