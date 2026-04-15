create table stg.dim_sellers as
WITH seller_base AS (
    SELECT 
        seller_id,
        -- Force a single location per seller to prevent fact duplication
        MAX(seller_city) AS seller_city,
        MAX(seller_state) AS state_abbr
    FROM raw.olist_sellers_dataset
    GROUP BY seller_id
)
SELECT 
    seller_id,
    seller_city,
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
    END AS seller_state,
    -- Region classification for high-level bottleneck analysis
    CASE 
        WHEN state_abbr IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'North'
        WHEN state_abbr IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Northeast'
        WHEN state_abbr IN ('DF', 'GO', 'MS', 'MT') THEN 'Central-West'
        WHEN state_abbr IN ('ES', 'MG', 'RJ', 'SP') THEN 'Southeast'
        WHEN state_abbr IN ('PR', 'RS', 'SC') THEN 'South'
        ELSE 'Unknown'
    END AS brazil_region
FROM seller_base;
