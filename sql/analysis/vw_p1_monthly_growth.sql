/* ============================================================================
   View: core.vw_p1_monthly_growth
   Pillar: 1. Revenue & Growth
   Grain: Monthly
   Upstream: stg.fct_sales
   Purpose: Calculates MoM growth, Seasonality Index, and categorizes 
            months into Organic vs. Seasonal Peak based on revenue deviation.
============================================================================ */

/* ============================================================================
   View: core.vw_p1_monthly_growth (Version 2.0 - Rolling Baseline)
   Pillar: 1. Revenue & Growth
   Logic Change: Replaced look-ahead global average with a 3-month trailing 
                 average to eliminate data leakage.
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
    WHERE purchase_date >= '2017-01-01' 
      AND purchase_date <  '2018-09-01'
    GROUP BY DATE_TRUNC('month', purchase_date::TIMESTAMP)::DATE  
),

/*
global_metrics AS (
    -- Step 2: Calculate the baseline average monthly revenue for Seasonality Index
    SELECT AVG(current_month_revenue) AS avg_monthly_revenue
    FROM monthly_base
),
*/

rolling_metrics AS (
    -- Step 2: Use window functions to get previous month and trailing 3-month average
    SELECT
        *,
        LAG(current_month_revenue) OVER (ORDER BY sales_month) AS prev_month_revenue,
        
        -- Calculate the average of the 3 preceding months (excluding the current month)
        AVG(current_month_revenue) OVER (
            ORDER BY sales_month 
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS trailing_avg_3m
    FROM monthly_base
)


-- Step 3: Final calculations using the rolling baseline
SELECT 
    sales_month,
    TO_CHAR(DATE_TRUNC('month', sales_month::TIMESTAMP), 'Mon YYYY') AS sales_month_display,
    
    ROUND(current_month_sale::NUMERIC, 2)                            AS current_month_sale,
    ROUND(current_month_freight::NUMERIC, 2)                         AS current_month_freight,
    ROUND(current_month_revenue::NUMERIC, 2)                         AS current_month_revenue,
    ROUND(prev_month_revenue::NUMERIC, 2)                            AS prev_month_revenue,
    
    -- Growth Calculation
    ROUND(
        ((current_month_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0)) * 100, 
        2
    )::NUMERIC                                                       AS mom_growth_pct,
    
    -- Updated Seasonality Index: (Current Month / Trailing 3-Month Avg)
    ROUND((current_month_revenue / NULLIF(trailing_avg_3m, 0)) * 100, 2)::NUMERIC AS seasonality_index,

    total_orders,
    late_deliveries,
    ROUND((late_deliveries::NUMERIC / NULLIF(total_orders, 0)) * 100, 2)::NUMERIC      AS late_delivery_rate_pct,

    -- Dynamic Classification: Compare current to trailing average
    CASE 
        WHEN (current_month_revenue / NULLIF(trailing_avg_3m, 0)) > 1.20 THEN 'Seasonal Peak'
        WHEN (current_month_revenue / NULLIF(trailing_avg_3m, 0)) < 0.80 THEN 'Slow Period'
        -- Handle first few months where trailing_avg might be NULL
        WHEN trailing_avg_3m IS NULL THEN 'Initializing'
        ELSE 'Organic/Stable'
    END AS growth_classification,

    CASE 
        WHEN EXTRACT(MONTH FROM sales_month) = 11 THEN 'Black Friday'
        WHEN EXTRACT(MONTH FROM sales_month) = 12 THEN 'Holiday Season'
        WHEN EXTRACT(MONTH FROM sales_month) = 3  THEN 'Consumer Day'
        ELSE 'Regular'
    END AS cycle_event

FROM rolling_metrics;/* ============================================================================
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
