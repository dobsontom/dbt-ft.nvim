{{ config(materialized='incremental', unique_key='order_id') }}

with updated as (
    select order_id, updated_at
    from {{ ref('stg_orders') }}
    {% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
    {% else %}
    where updated_at >= '2020-01-01'
    {% endif %}
),

refunded as (
    select order_id
    from {{ ref('stg_refunds') }}
    {% if is_incremental() %}
    where refunded_at > (select max(updated_at) from {{ this }})
    {% else %}
    where refunded_at >= '2020-01-01'
    {% endif %}
)

select order_id from updated
union all
select order_id from refunded
