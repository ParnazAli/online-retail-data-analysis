/*
===============================================================================
 05_advanced_analysis.sql
-------------------------------------------------------------------------------
 Purpose : Deeper business analyses built on top of the cleaned data, using
           more advanced SQL techniques (window functions, self-joins,
           multi-level CTEs). These go beyond the original dashboard's scope
           and answer real retention / growth / cross-sell questions.

 Sections:
   1. Month-over-month sales growth        (window function: LAG)
   2. Cohort retention analysis            (self-join on customer first-purchase month)
   3. Customer Lifetime Value (CLV)        (per-customer revenue, tenure, order pace)
   4. Market basket analysis               (self-join on invoice_no for product pairs)
===============================================================================
*/

-- ---------------------------------------------------------------------------
-- 1. Month-over-month sales growth
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_monthly_growth;
CREATE VIEW v_monthly_growth AS
WITH monthly AS (
    SELECT
        invoice_year_month,
        SUM(total_price) AS total_sales,
        COUNT(DISTINCT invoice_no) AS total_orders,
        COUNT(DISTINCT customer_id) AS total_customers
    FROM transactions_enriched
    GROUP BY invoice_year_month
)
SELECT
    invoice_year_month,
    ROUND(total_sales, 2) AS total_sales,
    total_orders,
    total_customers,
    ROUND(total_sales - LAG(total_sales) OVER (ORDER BY invoice_year_month), 2) AS sales_change_vs_prev_month,
    ROUND(
        100.0 * (total_sales - LAG(total_sales) OVER (ORDER BY invoice_year_month))
        / NULLIF(LAG(total_sales) OVER (ORDER BY invoice_year_month), 0), 1
    ) AS sales_growth_pct
FROM monthly
ORDER BY invoice_year_month;

-- ---------------------------------------------------------------------------
-- 2. Cohort retention analysis
--    Each customer is assigned to a cohort = the month of their first
--    purchase. We then track, for each cohort, what % of those customers
--    were still active in each subsequent month (month index 0, 1, 2, ...).
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_cohort_retention;
CREATE VIEW v_cohort_retention AS
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(invoice_year_month) AS cohort_month
    FROM transactions_enriched
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
customer_months AS (
    SELECT DISTINCT
        t.customer_id,
        t.invoice_year_month,
        f.cohort_month,
        -- month index = number of calendar months since first purchase
        (CAST(STRFTIME('%Y', t.invoice_year_month || '-01') AS INT) * 12
         + CAST(STRFTIME('%m', t.invoice_year_month || '-01') AS INT))
        -
        (CAST(STRFTIME('%Y', f.cohort_month || '-01') AS INT) * 12
         + CAST(STRFTIME('%m', f.cohort_month || '-01') AS INT)) AS month_index
    FROM transactions_enriched t
    JOIN first_purchase f ON f.customer_id = t.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    cm.cohort_month,
    cm.month_index,
    COUNT(DISTINCT cm.customer_id) AS active_customers,
    cs.cohort_size,
    ROUND(100.0 * COUNT(DISTINCT cm.customer_id) / cs.cohort_size, 1) AS retention_pct
FROM customer_months cm
JOIN cohort_sizes cs ON cs.cohort_month = cm.cohort_month
GROUP BY cm.cohort_month, cm.month_index
ORDER BY cm.cohort_month, cm.month_index;

-- ---------------------------------------------------------------------------
-- 3. Customer Lifetime Value (CLV)
--    Simple, transparent CLV: total historical revenue, plus an estimated
--    monthly run-rate based on the customer's actual purchase pace
--    (revenue / active months as a customer), rather than a black-box model.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_customer_ltv;
CREATE VIEW v_customer_ltv AS
WITH customer_span AS (
    SELECT
        customer_id,
        MIN(invoice_date) AS first_purchase,
        MAX(invoice_date) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS total_orders,
        ROUND(SUM(total_price), 2) AS total_revenue,
        -- +1 so a single-month customer still divides by 1, not 0
        (CAST(JULIANDAY(MAX(invoice_date)) - JULIANDAY(MIN(invoice_date)) AS INT) / 30) + 1 AS active_months
    FROM transactions_enriched
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
)
SELECT
    customer_id,
    first_purchase,
    last_purchase,
    total_orders,
    total_revenue,
    active_months,
    ROUND(total_revenue / active_months, 2) AS avg_monthly_revenue,
    -- naive 12-month forward projection at the customer's current pace
    ROUND((total_revenue / active_months) * 12, 2) AS projected_12m_value
FROM customer_span
ORDER BY total_revenue DESC;

-- ---------------------------------------------------------------------------
-- 4. Market basket analysis
--    Which product pairs are most frequently bought together in the same
--    invoice. Self-join on invoice_no, product A ordered before product B
--    (by stock_code) to avoid counting each pair twice.
-- ---------------------------------------------------------------------------
DROP VIEW IF EXISTS v_market_basket;
CREATE VIEW v_market_basket AS
SELECT
    a.description AS product_a,
    b.description AS product_b,
    COUNT(DISTINCT a.invoice_no) AS times_bought_together
FROM transactions_enriched a
JOIN transactions_enriched b
    ON a.invoice_no = b.invoice_no
    AND a.stock_code < b.stock_code   -- avoid duplicate pairs and self-pairs
WHERE a.is_adjustment_code = 0
  AND b.is_adjustment_code = 0
  AND a.description IS NOT NULL
  AND b.description IS NOT NULL
GROUP BY a.description, b.description
HAVING COUNT(DISTINCT a.invoice_no) >= 30
ORDER BY times_bought_together DESC
LIMIT 20;

-- Preview
SELECT * FROM v_monthly_growth;
SELECT * FROM v_cohort_retention WHERE month_index <= 3 LIMIT 20;
SELECT * FROM v_customer_ltv LIMIT 10;
SELECT * FROM v_market_basket LIMIT 10;
