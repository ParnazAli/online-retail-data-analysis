/*
===============================================================================
 04_business_insights.sql
-------------------------------------------------------------------------------
 Purpose : Business-facing aggregate queries, saved as views so they can be
           refreshed automatically and queried directly, or exported for the
           Power BI dashboard (see scripts/02_export_for_powerbi.py).
===============================================================================
*/

-- 1. Monthly sales trend
DROP VIEW IF EXISTS v_monthly_sales;
CREATE VIEW v_monthly_sales AS
SELECT
    invoice_year_month,
    ROUND(SUM(total_price), 2) AS total_sales,
    COUNT(DISTINCT invoice_no) AS total_orders
FROM transactions_enriched
GROUP BY invoice_year_month
ORDER BY invoice_year_month;

-- 2. Top 10 products by quantity sold (excludes non-product admin codes
--    such as POST, DOT, M — see sql/01_data_cleaning.sql, Step 5)
DROP VIEW IF EXISTS v_top_10_products;
CREATE VIEW v_top_10_products AS
SELECT
    description AS product,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(total_price), 2) AS total_revenue
FROM transactions_enriched
WHERE description IS NOT NULL
  AND is_adjustment_code = 0
GROUP BY description
ORDER BY total_quantity DESC
LIMIT 10;

-- 3. Top 5 countries by sales and quantity (excluding UK-dominant skew is NOT
--    applied here — kept as-is to match the original business question)
DROP VIEW IF EXISTS v_top_5_countries_sales;
CREATE VIEW v_top_5_countries_sales AS
SELECT
    country,
    ROUND(SUM(total_price), 2) AS total_sales,
    SUM(quantity) AS total_quantity
FROM transactions_enriched
GROUP BY country
ORDER BY total_sales DESC
LIMIT 5;

-- 4. Top 5 countries by number of distinct customers
DROP VIEW IF EXISTS v_top_5_countries_customers;
CREATE VIEW v_top_5_countries_customers AS
SELECT
    country,
    COUNT(DISTINCT customer_id) AS num_customers
FROM transactions_enriched
WHERE customer_id IS NOT NULL
GROUP BY country
ORDER BY num_customers DESC
LIMIT 5;

-- 5. Order distribution by time-of-day bucket
DROP VIEW IF EXISTS v_order_distribution;
CREATE VIEW v_order_distribution AS
SELECT
    time_of_day_bucket,
    COUNT(DISTINCT invoice_no) AS total_orders
FROM transactions_enriched
WHERE time_of_day_bucket != 'Other'
GROUP BY time_of_day_bucket;

-- 6. Peak hours (hour-by-hour order volume)
DROP VIEW IF EXISTS v_peak_hours;
CREATE VIEW v_peak_hours AS
SELECT
    invoice_hour,
    COUNT(DISTINCT invoice_no) AS total_orders
FROM transactions_enriched
GROUP BY invoice_hour
ORDER BY invoice_hour;

-- 7. Sales contribution by customer segment (requires customer_rfm)
DROP VIEW IF EXISTS v_sales_contribution_by_segment;
CREATE VIEW v_sales_contribution_by_segment AS
SELECT
    r.customer_segment,
    ROUND(SUM(t.total_price), 2) AS total_sales
FROM transactions_enriched t
JOIN customer_rfm r ON r.customer_id = t.customer_id
GROUP BY r.customer_segment
ORDER BY total_sales DESC;

-- 8. Customer distribution by segment
DROP VIEW IF EXISTS v_customer_distribution;
CREATE VIEW v_customer_distribution AS
SELECT
    customer_segment,
    COUNT(*) AS num_customers
FROM customer_rfm
GROUP BY customer_segment
ORDER BY num_customers DESC;

-- Preview all views
SELECT * FROM v_monthly_sales;
SELECT * FROM v_top_10_products;
SELECT * FROM v_top_5_countries_sales;
SELECT * FROM v_top_5_countries_customers;
SELECT * FROM v_order_distribution;
SELECT * FROM v_sales_contribution_by_segment;
SELECT * FROM v_customer_distribution;
