select order_id
from {{ ref('orders') }}
where status = {{ 'completed' if target.name == 'prod' else 'placed' }}
