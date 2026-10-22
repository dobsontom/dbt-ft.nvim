with source_orders as (
    select order_id, status
    from "warehouse"."analytics"."stg_orders"
)

select
    order_id,
    upper(status) as status
from source_orders
