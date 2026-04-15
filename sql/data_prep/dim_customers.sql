create table stg.dim_customers as
WITH customer_aggregates AS (
    SELECT 
        ocd.customer_unique_id,
        -- Forcing the most recent location to avoid row duplication
        MAX(ocd.customer_city) as customer_city, 
        MAX(ocd.customer_state) as state_abbr,
        MIN(ood.order_purchase_timestamp) as first_order,
        MAX(ood.order_purchase_timestamp) as recent_order,
        -- LTM as total days (Integer)
        EXTRACT(DAY FROM (MAX(ood.order_purchase_timestamp) - MIN(ood.order_purchase_timestamp))) as customer_lifespan_days
    FROM raw.olist_customers_dataset ocd 
    LEFT JOIN raw.olist_orders_dataset ood ON ocd.customer_id = ood.customer_id 
    GROUP BY ocd.customer_unique_id 
)
SELECT
    customer_unique_id,
    customer_city,
    -- Full state name mapping
    CASE state_abbr
        WHEN 'AC' THEN 'Acre' WHEN 'AL' THEN 'Alagoas' WHEN 'AM' THEN 'Amazonas'
        WHEN 'AP' THEN 'Amapá' WHEN 'BA' THEN 'Bahia' WHEN 'CE' THEN 'Ceará'
        WHEN 'DF' THEN 'Distrito Federal' WHEN 'ES' THEN 'Espírito Santo'
        WHEN 'GO' THEN 'Goiás' WHEN 'MA' THEN 'Maranhão' WHEN 'MG' THEN 'Minas Gerais'
        WHEN 'MS' THEN 'Mato Grosso do Sul' WHEN 'MT' THEN 'Mato Grosso'
        WHEN 'PA' THEN 'Pará' WHEN 'PB' THEN 'Paraíba' WHEN 'PE' THEN 'Pernambuco'
        WHEN 'PI' THEN 'Piauí' WHEN 'PR' THEN 'Paraná' WHEN 'RJ' THEN 'Rio de Janeiro'
        WHEN 'RN' THEN 'Rio Grande do Norte' WHEN 'RO' THEN 'Rondônia'
        WHEN 'RR' THEN 'Roraima' WHEN 'RS' THEN 'Rio Grande do Sul'
        WHEN 'SC' THEN 'Santa Catarina' WHEN 'SE' THEN 'Sergipe'
        WHEN 'SP' THEN 'São Paulo' WHEN 'TO' THEN 'Tocantins'
        ELSE 'Unknown'
    END AS customer_state,
    -- Region mapping
    CASE 
        WHEN state_abbr IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'North'
        WHEN state_abbr IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Northeast'
        WHEN state_abbr IN ('DF', 'GO', 'MS', 'MT') THEN 'Central-West'
        WHEN state_abbr IN ('ES', 'MG', 'RJ', 'SP') THEN 'Southeast'
        WHEN state_abbr IN ('PR', 'RS', 'SC') THEN 'South'
        ELSE 'Unknown'
    END AS brazil_region,
    first_order,
    recent_order,
    customer_lifespan_days,
    -- Retention Logic: Flagging repeat buyers at the source
    CASE WHEN recent_order > first_order THEN 1 ELSE 0 END as is_repeat_buyer
FROM customer_aggregates;
