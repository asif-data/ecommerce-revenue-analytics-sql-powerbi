create table stg.dim_products as
WITH product_physics AS (
    SELECT
        opd.product_id,
        CASE 
            WHEN pcnt.product_category_name_english IS NULL OR pcnt.product_category_name_english = '' 
            THEN opd.product_category_name
            ELSE pcnt.product_category_name_english
        END AS product_category,
        opd.product_weight_g,
        -- volume calculation
        (opd.product_length_cm * opd.product_width_cm * opd.product_height_cm) AS volume_cm3
    FROM raw.olist_products_dataset opd 
    LEFT JOIN raw.product_category_name_translation pcnt 
    ON opd.product_category_name = pcnt.product_category_name 
)
SELECT 
    product_id,
    product_category,
    product_weight_g,
    volume_cm3,
    CASE 
        WHEN volume_cm3 IS NULL THEN 'Unknown'
        WHEN volume_cm3 < 5000 THEN 'Small'
        WHEN volume_cm3 <= 20000 THEN 'Medium'
        WHEN volume_cm3 <= 50000 THEN 'Large'
        ELSE 'Extra Large'
    END AS volume_category
FROM product_physics;
