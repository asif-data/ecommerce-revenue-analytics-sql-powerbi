/* ============================================================================
   View: core.vw_p4_unit_economics
   Pillar: 4. Unit Economics (Efficiency & Margins)
   Grain: Order Item (sales_key)
   Upstream: stg.fct_sales, stg.dim_orders, stg.dim_sellers
   Update: Shifted "Expensive" logic to transaction-level outliers.
============================================================================ */

CREATE OR REPLACE VIEW core.vw_p4_unit_economics AS

WITH base_metrics AS (
    -- Step 1: Gather raw data and calculate regional baselines
    SELECT 
        s.sales_key,
        s.price,
        s.freight_value,
        NULLIF(o.review_score, -1)                          AS review_score,
        o.max_installments,
        o.total_order_payment_value,
        ds.seller_state,
        ds.brazil_region,
        
        -- Window Function: The average cost for THIS specific region
        AVG(s.freight_value) OVER(PARTITION BY ds.brazil_region) AS regional_avg_freight
    FROM stg.fct_sales s 
    LEFT JOIN stg.dim_orders o ON s.order_id = o.order_id 
    LEFT JOIN stg.dim_sellers ds ON s.seller_id = ds.seller_id 
),

calculated_fields AS (
    -- Step 2: Calculate ratios and efficiency scores
    SELECT 
        *,
        -- Freight-to-Price Ratio
        ROUND((freight_value / NULLIF(price, 0))::NUMERIC, 4) AS freight_ratio,
        
        -- Efficiency Index: How does this order compare to its regional peers?
        -- 1.0 = Average, > 1.0 = Expensive for this region
        ROUND((freight_value / NULLIF(regional_avg_freight, 0))::NUMERIC, 2) AS regional_efficiency_index
    FROM base_metrics
)

-- Step 3: Final Categorization for Power BI
SELECT 
    *,
    -- Identify transaction-level outliers instead of regional ones
    CASE  
        WHEN regional_efficiency_index > 1.5 THEN 'Critical Outlier (>1.5x Avg)'
        WHEN regional_efficiency_index > 1.1 THEN 'Expensive Transaction'
        WHEN regional_efficiency_index < 0.9 THEN 'Efficient Transaction'
        ELSE 'Regional Baseline'
    END AS transaction_efficiency_status,

    -- Freight-to-Price Bins for Sentiment Analysis
    CASE 
        WHEN freight_ratio <= 0.10 THEN '0-10% (Low)'
        WHEN freight_ratio <= 0.20 THEN '10-20% (Mid)'
        WHEN freight_ratio <= 0.50 THEN '20-50% (High)'
        ELSE '50%+ (Critical)'
    END AS freight_ratio_bucket,
    
    -- Installment Groups for AOV Analysis
    CASE 
        WHEN max_installments <= 1  THEN 'Single Pay'
        WHEN max_installments <= 5  THEN 'Short-term (2-5)'
        WHEN max_installments <= 10 THEN 'Mid-term (6-10)'
        ELSE 'Long-term (10+)'
    END AS installment_group

FROM calculated_fields;
