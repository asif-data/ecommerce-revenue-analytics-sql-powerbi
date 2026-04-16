/* ============================================================================
   View: core.vw_p5_strategic_risk_map
   Pillar: 5. Strategic Risk (The "Threat" Map)
   Update: Refined join keys and added 'Uncategorized' handling for 
            blank product categories.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_p5_strategic_risk_map AS

WITH seller_category_performance AS (
    -- Step 1: Aggregate data with robust NULL handling
    SELECT 
        -- Handle blank or NULL categories to ensure they show up in the report
        COALESCE(NULLIF(p.product_category, ''), 'Uncategorized') AS product_category,
        f.seller_id,
        ds.seller_state,
        ds.brazil_region                                    AS seller_region,
        dc.customer_state,
        dc.brazil_region                                    AS customer_region,
        SUM(f.item_total_value)                             AS seller_category_revenue,
        COUNT(f.order_id)                                   AS total_category_orders,
        AVG(NULLIF(o.review_score, -1))                     AS avg_lane_review,
        -- Using f.is_late as per your updated fact table structure
        SUM(f.is_late)                                      AS total_late_orders
    FROM stg.fct_sales f
    JOIN stg.dim_products p   ON f.product_id = p.product_id 
    JOIN stg.dim_sellers ds   ON f.seller_id = ds.seller_id
    -- Using the updated unique ID join key
    JOIN stg.dim_customers dc ON f.customer_unique_id = dc.customer_unique_id  
    JOIN stg.dim_orders o     ON f.order_id = o.order_id
    GROUP BY 1, 2, 3, 4, 5, 6
),

seller_concentration AS (
    -- Step 2: Calculate dependency ratio (Who owns the category?)
    SELECT 
        *,
        PERCENT_RANK() OVER(
            PARTITION BY product_category 
            ORDER BY seller_category_revenue DESC
        ) AS seller_revenue_rank
    FROM seller_category_performance
)

-- Step 3: Final Risk Mapping
SELECT 
    *,
    seller_state || ' -> ' || customer_state                AS transit_lane,
    
    CASE 
        WHEN seller_region = customer_region THEN 'Intra-Region'
        ELSE 'Cross-Region'
    END AS shipping_type,

    CASE 
        WHEN seller_revenue_rank <= 0.05 THEN 'High Dependency Seller (Top 5%)'
        ELSE 'Long Tail Seller'
    END AS dependency_segment,

    ROUND(
        (total_late_orders::NUMERIC / NULLIF(total_category_orders, 0)) * 100, 
        2
    ) AS lane_late_rate_pct,

    CASE 
        WHEN (total_late_orders::NUMERIC / NULLIF(total_category_orders, 0)) > 0.20 
             AND avg_lane_review < 3.5 THEN 'Critical Risk Lane'
        WHEN (total_late_orders::NUMERIC / NULLIF(total_category_orders, 0)) > 0.15 THEN 'Logistical Bottleneck'
        ELSE 'Stable Lane'
    END AS strategic_risk_status

FROM seller_concentration;
