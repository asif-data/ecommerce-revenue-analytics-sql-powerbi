/* ============================================================================
   View: core.vw_p3_product_quality_matrix
   Pillar: 3. Product & Category (Inventory & Quality)
   Grain: One row per product_category
   Upstream: stg.dim_products, stg.fct_sales, stg.dim_orders
   Purpose: Identifies Pareto drivers and "Toxicity" (low sentiment) 
            to optimize product mix and investigate logistics/quality traps.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_p3_product_quality_matrix AS

WITH category_metrics AS (
    -- Step 1: Aggregate revenue and reviews at the category grain
    SELECT 
        p.product_category,
        SUM(f.item_total_value)                            AS total_revenue,
        COUNT(DISTINCT f.order_id)                         AS total_orders,
        AVG(o.review_score)                                AS avg_review_score,
        -- Toxicity: Count only the critical failures (1-star)
        COUNT(CASE WHEN o.review_score = 1 THEN 1 END)     AS one_star_count,
        COUNT(o.review_score)                              AS total_reviews
    FROM stg.fct_sales f
    JOIN stg.dim_products p ON f.product_id = p.product_id
    JOIN stg.dim_orders o ON f.order_id = o.order_id
    GROUP BY p.product_category
),

time_bound_growth AS (
    -- Step 2: Calculate Recent vs. Previous revenue for lifecycle tagging
    -- Using the dataset max date to avoid hardcoding
    SELECT 
        p.product_category,
        SUM(CASE WHEN f.purchase_date >= (SELECT MAX(purchase_date) - INTERVAL '90 days' FROM stg.fct_sales) 
                 THEN f.item_total_value ELSE 0 END) AS recent_rev,
        SUM(CASE WHEN f.purchase_date < (SELECT MAX(purchase_date) - INTERVAL '90 days' FROM stg.fct_sales)
                 AND f.purchase_date >= (SELECT MAX(purchase_date) - INTERVAL '180 days' FROM stg.fct_sales)
                 THEN f.item_total_value ELSE 0 END) AS prev_rev
    FROM stg.fct_sales f
    JOIN stg.dim_products p ON f.product_id = p.product_id
    GROUP BY p.product_category
),

pareto_calc AS (
    -- Step 3: Use window functions for cumulative share
    SELECT 
        m.*,
        t.recent_rev,
        t.prev_rev,
        SUM(m.total_revenue) OVER() AS global_total_revenue,
        -- Cumulative sum to find the 80% cutoff
        SUM(m.total_revenue) OVER(ORDER BY m.total_revenue DESC) AS cumulative_revenue
    FROM category_metrics m
    JOIN time_bound_growth t ON m.product_category = t.product_category
)

-- Step 4: Final output with Toxicity and Pareto Classification
SELECT 
    product_category,
    ROUND(total_revenue::NUMERIC, 2)                       AS total_revenue,
    total_orders,
    
    -- Pareto Tagging: The 80/20 Rule
    CASE 
        WHEN (cumulative_revenue / global_total_revenue) <= 0.80 THEN 'Pareto Driver (Top 80%)'
        ELSE 'Long Tail'
    END AS revenue_segment,
    
    ROUND(avg_review_score::NUMERIC, 2)                    AS avg_review_score,
    
    -- Toxicity Ratio: % of 1-star reviews
    ROUND((one_star_count::NUMERIC / NULLIF(total_reviews, 0)) * 100, 2) AS toxicity_ratio_pct,
    
    -- Quality-Volume Matrix Classification
    CASE 
        WHEN total_revenue > (SELECT AVG(total_revenue) FROM category_metrics) AND avg_review_score >= 4.0 THEN 'Core Strengths'
        WHEN total_revenue > (SELECT AVG(total_revenue) FROM category_metrics) AND avg_review_score < 3.5  THEN 'Revenue Traps'
        WHEN total_revenue <= (SELECT AVG(total_revenue) FROM category_metrics) AND avg_review_score >= 4.0 THEN 'Niche Winners'
        ELSE 'Underperformers'
    END AS matrix_position,
    
    -- Lifecycle Status (Emerging vs. Declining)
    CASE 
        WHEN prev_rev = 0 THEN 'New'
        WHEN (recent_rev - prev_rev) / prev_rev > 0.20 THEN 'Emerging'
        WHEN (recent_rev - prev_rev) / prev_rev < -0.10 THEN 'Declining'
        ELSE 'Stable'
    END AS lifecycle_status

FROM pareto_calc
ORDER BY total_revenue DESC;
