/* ============================================================================
   View: core.vw_p2_customer_journey
   Pillar: 2. Customer Intelligence (Loyalty & Retention)
   Grain: One row per customer_unique_id
   Fix: Included total_lifetime_orders to support downstream win-back logic.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_p2_customer_journey AS

WITH customer_stats AS (
    -- Step 1: Aggregate revenue and order count per customer
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT order_id) AS total_lifetime_orders,
        SUM(item_total_value)    AS total_lifetime_revenue
    FROM stg.fct_sales
    GROUP BY customer_unique_id
),

first_and_second_orders AS (
    -- Step 2: Sequence orders to find touchpoints
    SELECT 
        customer_unique_id,
        order_id,
        purchase_date,
        order_seq
    FROM (
        SELECT 
            customer_unique_id,
            order_id,
            purchase_date,
            ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY purchase_date) AS order_seq
        FROM stg.fct_sales
    ) t
    WHERE order_seq <= 2
),

today_anchor AS (
    SELECT MAX(purchase_date)::DATE AS max_date FROM stg.fct_sales
)

-- Step 3: Final Selection
SELECT 
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    c.first_order::DATE                                      AS first_order_date,
    o1.review_score                                          AS first_order_review_score,
    fso2.purchase_date::DATE                                 AS second_order_date,
    
    CASE 
        WHEN fso2.purchase_date::DATE > c.first_order::DATE 
             AND (fso2.purchase_date::DATE - c.first_order::DATE) <= 90 THEN 1 
        ELSE 0 
    END AS is_returned_90d,

    c.recent_order::DATE                                     AS recent_order_date,
    
    -- Frequency & Monetary metrics
    s.total_lifetime_orders,
    ROUND(s.total_lifetime_revenue::NUMERIC, 2)              AS total_lifetime_revenue,
    
    (c.customer_lifespan_days + 1)                           AS customer_lifespan_days,
    c.is_repeat_buyer,
    
    (ta.max_date - c.recent_order::DATE)                     AS recency_days,
    CASE 
        WHEN (ta.max_date - c.recent_order::DATE) > 180 THEN 1 
        ELSE 0 
    END AS is_churned

FROM stg.dim_customers c
JOIN customer_stats s ON c.customer_unique_id = s.customer_unique_id
CROSS JOIN today_anchor ta
LEFT JOIN first_and_second_orders fso1 ON c.customer_unique_id = fso1.customer_unique_id AND fso1.order_seq = 1
LEFT JOIN stg.dim_orders o1 ON fso1.order_id = o1.order_id
LEFT JOIN first_and_second_orders fso2 ON c.customer_unique_id = fso2.customer_unique_id AND fso2.order_seq = 2;
