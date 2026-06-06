-- Compare segments by revenue and promo dependency
SELECT 
    revenue_loyalty_segment,
    promo_dependency_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spend), 2) AS avg_spend,
    ROUND(AVG(promo_order_ratio), 2) AS avg_promo_ratio,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value,
    ROUND(AVG(`Review Rating`), 1) AS avg_rating
FROM customer_features
GROUP BY revenue_loyalty_segment, promo_dependency_segment
ORDER BY avg_spend DESC;

-- List genuinely loyal vs discount hunters
SELECT 
    customer_id,
    total_spend,
    promo_order_ratio,
    revenue_loyalty_segment,
    promo_dependency_segment,
    is_ideal_customer AS genuinely_loyal_flag
FROM customer_features
WHERE (revenue_loyalty_segment = 'High Revenue' AND promo_dependency_segment = 'No Promo Dependency')
   OR (revenue_loyalty_segment = 'Low Revenue' AND promo_dependency_segment = 'High Promo Dependency');
   
-- Requires joining transactions for category breadth
SELECT 
    CASE 
        WHEN c.total_spend >= PERCENTILE_CONT(0.66) OVER() THEN 'High Value'
        ELSE 'Low/Medium Value' 
    END AS value_tier,
    ROUND(AVG(c.purchase_frequency), 1) AS avg_freq,
    ROUND(AVG(c.avg_order_value), 2) AS avg_aov,
    ROUND(AVG(c.discount_rate), 2) AS avg_discount_rate,
    ROUND(AVG(c.promo_order_ratio), 2) AS avg_promo_ratio,
    ROUND(AVG(c.`Review Rating`), 1) AS avg_rating,
    ROUND(AVG(COALESCE(cat.category_count, 0)), 1) AS avg_category_breadth
FROM customer_features c
LEFT JOIN (
    SELECT customer_id, COUNT(DISTINCT product_category) AS category_count
    FROM transactions
    GROUP BY customer_id
) cat ON c.customer_id = cat.customer_id
GROUP BY value_tier;

-- Geographic opportunity (requires transactions & customers)
SELECT 
    t.city,
    t.state,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    ROUND(AVG(c.total_spend), 2) AS avg_customer_spend,
    ROUND(AVG(c.promo_order_ratio), 2) AS avg_promo_ratio,
    ROUND(SUM(c.total_spend), 2) AS total_revenue,
    ROUND(AVG(c.total_spend) * (1 - AVG(c.promo_order_ratio)), 2) AS organic_potential_score
FROM customer_features c
JOIN transactions t ON c.customer_id = t.customer_id
GROUP BY t.city, t.state
HAVING customer_count >= 5
ORDER BY organic_potential_score DESC
LIMIT 10;

-- Demographic underlevered (age groups and gender)
SELECT 
    CASE 
        WHEN cu.age BETWEEN 18 AND 25 THEN '18-25'
        WHEN cu.age BETWEEN 26 AND 35 THEN '26-35'
        WHEN cu.age BETWEEN 36 AND 50 THEN '36-50'
        ELSE '50+' 
    END AS age_group,
    cu.gender,
    COUNT(DISTINCT c.customer_id) AS cust_count,
    ROUND(AVG(c.total_spend), 2) AS avg_spend,
    ROUND(AVG(c.promo_order_ratio), 2) AS avg_promo_ratio,
    ROUND(AVG(c.`Review Rating`), 1) AS avg_rating
FROM customer_features c
JOIN customers cu ON c.customer_id = cu.customer_id
GROUP BY age_group, cu.gender
ORDER BY avg_spend DESC;

-- Current state by promo dependency and revenue segment
SELECT 
    promo_dependency_segment,
    revenue_loyalty_segment,
    COUNT(*) AS customers,
    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(AVG(discount_rate), 2) AS avg_discount_rate,
    ROUND(SUM(discounted_spend), 2) AS discounted_revenue
FROM customer_features
GROUP BY promo_dependency_segment, revenue_loyalty_segment
ORDER BY total_revenue DESC;

-- Which promo-dependent segments contribute most discounted revenue?
SELECT 
    promo_dependency_segment,
    ROUND(SUM(discounted_spend), 2) AS total_discounted_spend,
    ROUND(SUM(total_spend), 2) AS total_spend,
    ROUND(SUM(discounted_spend) / NULLIF(SUM(total_spend), 0), 2) AS discount_share
FROM customer_features
GROUP BY promo_dependency_segment
ORDER BY discount_share DESC;

-- Profile of ideal customers (is_ideal_customer = TRUE)
SELECT 
    ROUND(AVG(total_spend), 2) AS avg_spend,
    ROUND(AVG(avg_order_value), 2) AS avg_aov,
    ROUND(AVG(`Review Rating`), 1) AS avg_rating,
    ROUND(AVG(promo_order_ratio), 2) AS avg_promo_ratio,
    -- These require transaction table
    (SELECT product_category FROM transactions t 
     WHERE t.customer_id IN (SELECT customer_id FROM customer_features WHERE is_ideal_customer = TRUE)
     GROUP BY product_category ORDER BY COUNT(*) DESC LIMIT 1) AS top_category,
    (SELECT payment_method FROM transactions t 
     WHERE t.customer_id IN (SELECT customer_id FROM customer_features WHERE is_ideal_customer = TRUE)
     GROUP BY payment_method ORDER BY COUNT(*) DESC LIMIT 1) AS preferred_payment,
    (SELECT shipping_method FROM transactions t 
     WHERE t.customer_id IN (SELECT customer_id FROM customer_features WHERE is_ideal_customer = TRUE)
     GROUP BY shipping_method ORDER BY COUNT(*) DESC LIMIT 1) AS preferred_shipping,
    ROUND(AVG(cat.category_count), 1) AS avg_category_breadth
FROM customer_features c
LEFT JOIN (
    SELECT customer_id, COUNT(DISTINCT product_category) AS category_count
    FROM transactions
    GROUP BY customer_id
) cat ON c.customer_id = cat.customer_id
WHERE c.is_ideal_customer = TRUE;

-- Compare ideal vs non-ideal
SELECT 
    CASE WHEN is_ideal_customer = 1 THEN 'Ideal' ELSE 'Non-Ideal' END AS segment,
    ROUND(AVG(total_spend), 2) AS avg_spend,
    ROUND(AVG(avg_order_value), 2) AS avg_aov,
    ROUND(AVG(promo_order_ratio), 2) AS avg_promo_ratio,
    ROUND(AVG(`Review Rating`), 1) AS avg_rating
FROM customer_features
GROUP BY is_ideal_customer;