/* ============================================================================
   View: core.vw_executive_summary
   Layer: Page 0. Executive Layer (The Health Check)
   Grain: Monthly
   Upstream: core.vw_p1_monthly_growth, stg.dim_orders, stg.fct_sales
   Purpose: High-level pulse check for C-suite. Detects "Toxic Growth" by 
            aligning revenue trends with customer sentiment and lost revenue.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_executive_summary AS

WITH monthly_sentiment AS (
    -- Step 1: Calculate monthly sentiment and fulfillment volume
    SELECT 
        DATE_TRUNC('month', order_purchase_timestamp)::DATE AS sales_month,
        AVG(NULLIF(review_score, -1))                       AS avg_review_score,
        COUNT(CASE WHEN order_status = 'delivered' THEN 1 END) AS delivered_count,
        COUNT(CASE WHEN order_status = 'canceled' THEN 1 END)  AS canceled_count,
        COUNT(order_id)                                     AS total_order_volume
    FROM stg.dim_orders
    WHERE order_purchase_timestamp >= '2017-01-01' 
      AND order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
),

lost_revenue_calc AS (
    -- Step 2: Quantify revenue lost to cancellations
    SELECT 
        DATE_TRUNC('month', f.purchase_date::TIMESTAMP)::DATE AS sales_month,
        SUM(f.item_total_value)                               AS canceled_revenue_loss
    FROM stg.fct_sales f
    JOIN stg.dim_orders o ON f.order_id = o.order_id
    WHERE o.order_status = 'canceled'
    GROUP BY 1
),

sentiment_trends AS (
    -- Step 3: Get previous month's sentiment for "Toxic Growth" detection
    SELECT 
        *,
        LAG(avg_review_score) OVER (ORDER BY sales_month) AS prev_month_sentiment
    FROM monthly_sentiment
)

-- Step 4: Final Harvest and Logic Assembly
SELECT 
    p1.sales_month,
    p1.sales_month_display,
    
    -- Top Line Growth (Harvested from Pillar 1)
    p1.current_month_revenue,
    p1.mom_growth_pct,
    
    -- Bottom Line Sentiment (Harvested from Staging)
    ROUND(s.avg_review_score::NUMERIC, 2)                    AS avg_review_score,
    
    -- Fulfillment Efficiency
    ROUND(
        (s.delivered_count::NUMERIC / NULLIF(s.total_order_volume, 0)) * 100, 
        2
    ) AS fulfillment_ratio_pct,
    
    -- Leakage: Revenue Lost to Canceled Orders
    COALESCE(ROUND(l.canceled_revenue_loss::NUMERIC, 2), 0)   AS canceled_revenue_loss,
    
    -- Hypothesis Testing: Toxic Growth Detection
    -- Definition: Revenue is up, but sentiment is down by > 2%
    CASE 
        WHEN p1.mom_growth_pct > 0 
             AND (s.avg_review_score < s.prev_month_sentiment * 0.98) THEN 'Toxic Growth'
        WHEN p1.mom_growth_pct > 0 
             AND s.avg_review_score >= s.prev_month_sentiment THEN 'Efficient Scaling'
        WHEN p1.mom_growth_pct < 0 THEN 'Contraction'
        ELSE 'Stable'
    END AS business_health_status,

    -- Logistics Warning (Harvested from Pillar 1)
    p1.late_delivery_rate_pct AS logistics_pressure_index

FROM core.vw_p1_monthly_growth p1
LEFT JOIN sentiment_trends s   ON p1.sales_month = s.sales_month
LEFT JOIN lost_revenue_calc l  ON p1.sales_month = l.sales_month;
