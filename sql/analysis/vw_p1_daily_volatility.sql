/* ============================================================================
   View: core.vw_p1_daily_volatility
   Pillar: 1. Revenue & Growth
   Grain: Daily
   Upstream: stg.fct_sales
   Purpose: Tracks daily revenue stability and calculates rolling 30-day 
            averages and standard deviations (volatility) to smooth noise.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_p1_daily_volatility AS

WITH daily_base AS (
    -- Step 1: Aggregate at the pure daily grain
    SELECT 
        purchase_date::DATE         AS sales_date,
        SUM(t.price)                AS current_day_sale,
        SUM(t.freight_value)        AS current_day_freight,
        SUM(t.item_total_value)     AS current_day_revenue,
        COUNT(DISTINCT t.order_id)  AS total_orders
    FROM stg.fct_sales t 
    -- Maintain the same reliable timeframe as the monthly view
    WHERE purchase_date >= '2017-01-01' 
      AND purchase_date <  '2018-09-01'
    GROUP BY purchase_date::DATE 
),

rolling_metrics AS (
    -- Step 2: Apply statistical window functions for rolling metrics
    SELECT
        sales_date,
        current_day_sale,
        current_day_freight,
        current_day_revenue,
        total_orders,
        
        -- Smooth out weekend/weekday dips with a 30-day moving average
        AVG(current_day_revenue) OVER (
            ORDER BY sales_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW 
        ) AS revenue_average_30d,
        
        -- Calculate unpredictability. COALESCE handles the NULL on day 1.
        COALESCE(
            STDDEV_SAMP(current_day_revenue) OVER (
                ORDER BY sales_date 
                ROWS BETWEEN 29 PRECEDING AND CURRENT ROW 
            ), 0
        ) AS revenue_volatility_30d
    FROM daily_base
)

-- Step 3: Final output with strict numeric formatting
SELECT
    sales_date,
    ROUND(current_day_sale::NUMERIC, 2)       AS current_day_sale,
    ROUND(current_day_freight::NUMERIC, 2)    AS current_day_freight,
    ROUND(current_day_revenue::NUMERIC, 2)    AS current_day_revenue,
    total_orders,
    ROUND(revenue_average_30d::NUMERIC, 2)    AS revenue_average_30d,
    ROUND(revenue_volatility_30d::NUMERIC, 2) AS revenue_volatility_30d
FROM rolling_metrics;
