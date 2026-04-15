/* ============================================================================
   View: core.vw_p1_monthly_growth
   Pillar: 1. Revenue & Growth
   Grain: Monthly
   Upstream: stg.fct_sales
   Purpose: Calculates Month-over-Month (MoM) revenue growth and tracks 
            late delivery rates to identify logistics pressure during peaks.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_p1_monthly_growth AS

WITH monthly_base AS (
    -- Step 1: Aggregate at the pure monthly grain
    SELECT 
        DATE_TRUNC('month', purchase_date::TIMESTAMP)::DATE AS sales_month,
        SUM(t.price)                                        AS current_month_sale,
        SUM(t.freight_value)                                AS current_month_freight,
        SUM(t.item_total_value)                             AS current_month_revenue,
        COUNT(DISTINCT t.order_id)                          AS total_orders,
        SUM(t.is_late)                                      AS late_deliveries
    FROM stg.fct_sales t 
    -- Filter out fragmented startup data (2016) and incomplete cut-off data (Sep 2018)
    WHERE purchase_date >= '2017-01-01' 
      AND purchase_date <  '2018-09-01'
    GROUP BY DATE_TRUNC('month', purchase_date::TIMESTAMP)::DATE  
),

mom_calculations AS (
    -- Step 2: Fetch previous month's revenue using window functions
    SELECT
        sales_month,
        current_month_sale,
        current_month_freight,
        current_month_revenue,
        LAG(current_month_revenue) OVER (ORDER BY sales_month) AS prev_month_revenue,
        total_orders,
        late_deliveries
    FROM monthly_base 
)

-- Step 3: Final growth and logistics pressure calculations
SELECT 
    sales_month,
    -- Formatted string for dashboard labels (e.g., 'Jan 2017')
    TO_CHAR(DATE_TRUNC('month', sales_month::TIMESTAMP), 'Mon YYYY') AS sales_month_display,
    
    -- Cast all financials to exact 2-decimal numerics for BI standardization
    ROUND(current_month_sale::NUMERIC, 2)                            AS current_month_sale,
    ROUND(current_month_freight::NUMERIC, 2)                         AS current_month_freight,
    ROUND(current_month_revenue::NUMERIC, 2)                         AS current_month_revenue,
    ROUND(prev_month_revenue::NUMERIC, 2)                            AS prev_month_revenue,
    ROUND((current_month_revenue - prev_month_revenue)::NUMERIC, 2)  AS mom_revenue_diff,
    
    -- Safe division using NULLIF to prevent divide-by-zero on the first month
    ROUND(
        ((current_month_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0)) * 100, 
        2
    )::NUMERIC                                                       AS mom_growth_pct,
    
    total_orders,
    late_deliveries,
    
    -- Logistics Pressure Index: % of total orders that were late
    ROUND(
        (late_deliveries::NUMERIC / NULLIF(total_orders, 0)) * 100, 
        2
    )::NUMERIC                                                       AS late_delivery_rate_pct
FROM mom_calculations;
