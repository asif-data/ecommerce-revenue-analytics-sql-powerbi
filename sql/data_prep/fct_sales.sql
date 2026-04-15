create table stg.fct_sales as
SELECT 
    -- Surrogate Key (Faster for Power BI relationships)
    ROW_NUMBER() OVER (ORDER BY ooid.order_id, ooid.order_item_id)::BIGINT AS sales_key,
    -- 2. Keys
    ooid.order_id,
    ooid.order_item_id AS item_sequence_number,
    ooid.product_id,
    ocd.customer_unique_id,
    ooid.seller_id,
    -- 3. Measures
    ooid.price,
    ooid.freight_value,
    ROUND((ooid.price + ooid.freight_value)::NUMERIC, 2) AS item_total_value,
    -- 4. Logistics Intelligence (Calculated in Days as a Decimal)
    CASE 
        WHEN ood.order_delivered_customer_date IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (ood.order_delivered_customer_date - ood.order_purchase_timestamp))/86400 
        ELSE NULL 
    END AS days_to_delivery,
    -- 5. Status Flags (Casted to INT for easier summation)
    CASE 
        WHEN ood.order_delivered_customer_date > ood.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END::INT AS is_late,
    CASE 
        WHEN ood.order_status = 'delivered' THEN 1 
        ELSE 0 
    END::INT AS is_delivered,
    -- 6. Date Reference
    ood.order_purchase_timestamp::DATE AS purchase_date
FROM raw.olist_order_items_dataset ooid 
LEFT JOIN raw.olist_orders_dataset ood ON ooid.order_id = ood.order_id 
LEFT JOIN raw.olist_customers_dataset ocd ON ood.customer_id = ocd.customer_id;
