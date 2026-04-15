create table stg.dim_orders as
WITH order_payments AS (
    SELECT 
        order_id,
        MAX(payment_type) AS primary_payment_type, 
        MAX(payment_installments) AS max_installments,
        SUM(payment_value) AS total_order_payment_value
    FROM raw.olist_order_payments_dataset
    GROUP BY order_id
),
order_reviews AS (
    SELECT 
        order_id,
        -- Force grain to 1 row per order_id
        COALESCE(AVG(review_score), -1) AS avg_review_score 
    FROM raw.cleaned_reviews
    GROUP BY order_id 
),
order_basket_size AS (
    SELECT 
        order_id,
        COUNT(order_item_id) AS basket_size
    FROM raw.olist_order_items_dataset
    GROUP BY order_id
)
SELECT
    ood.order_id,
    ood.customer_id, -- Keep as link, but use unique_id in Fact/Customer dim
    ood.order_status,
    -- Timestamps for lifecycle analysis 
    ood.order_purchase_timestamp,
    ood.order_approved_at,
    ood.order_delivered_carrier_date,
    ood.order_delivered_customer_date,
    ood.order_estimated_delivery_date,
    -- Payment Metadata 
    op.total_order_payment_value,
    op.primary_payment_type,
    op.max_installments,
    -- Sentiment Metadata
    ROUND(orv.avg_review_score::numeric, 2) AS review_score,
    COALESCE(obs.basket_size, 0) AS basket_size
FROM raw.olist_orders_dataset ood 
LEFT JOIN order_payments op ON ood.order_id = op.order_id 
LEFT JOIN order_reviews orv ON ood.order_id = orv.order_id
LEFT JOIN order_basket_size obs ON ood.order_id = obs.order_id;
