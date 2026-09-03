/*
===============================================================================
 02_feature_engineering.sql
-------------------------------------------------------------------------------
 Purpose : Add derived columns needed for downstream analysis and for the
           Power BI dashboard (line revenue, calendar parts, time-of-day
           buckets). Built on top of clean_transactions.
===============================================================================
*/

DROP TABLE IF EXISTS transactions_enriched;
CREATE TABLE transactions_enriched AS
SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    ROUND(quantity * unit_price, 2)                      AS total_price,
    invoice_date,
    CAST(STRFTIME('%Y', invoice_date) AS INTEGER)         AS invoice_year,
    CAST(STRFTIME('%m', invoice_date) AS INTEGER)         AS invoice_month,
    STRFTIME('%Y-%m', invoice_date)                       AS invoice_year_month,
    CASE CAST(STRFTIME('%w', invoice_date) AS INTEGER)
        WHEN 0 THEN 'Sunday'    WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'   WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'  WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END                                                   AS invoice_day_name,
    CAST(STRFTIME('%H', invoice_date) AS INTEGER)          AS invoice_hour,
    CASE
        WHEN CAST(STRFTIME('%H', invoice_date) AS INTEGER) BETWEEN 6  AND 8  THEN '6 AM - 9 AM'
        WHEN CAST(STRFTIME('%H', invoice_date) AS INTEGER) BETWEEN 9  AND 12 THEN '10 AM - 1 PM'
        WHEN CAST(STRFTIME('%H', invoice_date) AS INTEGER) BETWEEN 13 AND 16 THEN '2 PM - 5 PM'
        WHEN CAST(STRFTIME('%H', invoice_date) AS INTEGER) BETWEEN 17 AND 20 THEN '6 PM - 9 PM'
        ELSE 'Other'
    END                                                   AS time_of_day_bucket,
    customer_id,
    country,
    has_customer_id,
    has_description,
    is_adjustment_code,
    is_outlier_quantity,
    is_outlier_price
FROM clean_transactions;

-- Sanity check
SELECT COUNT(*) AS row_count,
       ROUND(SUM(total_price), 2) AS total_revenue,
       MIN(invoice_date) AS min_date,
       MAX(invoice_date) AS max_date
FROM transactions_enriched;
