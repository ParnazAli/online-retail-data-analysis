/*
===============================================================================
 01_data_cleaning.sql
-------------------------------------------------------------------------------
 Purpose : Clean raw_transactions and produce a trustworthy analytical base
           table (clean_transactions) for all downstream analysis, with a
           full audit trail of every cleaning decision.

 Source  : raw_transactions (541,910 rows, loaded as-is — see
           scripts/01_load_raw_data.py)

 Cleaning steps (each justified, logged, not silently applied):

   1. Cancelled orders (invoice_no starts with "C") -> separated out.
   2. Non-positive quantity or price -> removed (fees/adjustments/errors).
   3. Exact duplicate rows -> removed.
   4. Text standardization -> country names unified (e.g. "EIRE" -> "Ireland"),
      whitespace collapsed in description.
   5. Administrative / non-product stock codes (POST, DOT, M, C2, D, S,
      BANK CHARGES, AMAZONFEE, CRUK, B) -> flagged, not removed, so they can
      still be excluded from product-level analysis without losing revenue
      totals.
   6. Statistical outliers in quantity/price -> flagged using the IQR method
      (not removed — flagged, since a single big wholesale order is a real,
      valid transaction, not necessarily bad data).
   7. Missing Customer ID / missing description -> flagged (kept).

 Output tables:
   - clean_transactions      : validated sales rows, with quality flags
   - cancelled_transactions  : cancellation/return rows, kept separately
   - data_quality_log        : audit trail — what was checked, what happened
===============================================================================
*/

-- ---------------------------------------------------------------------------
-- Step 0: Audit log table
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS data_quality_log;
CREATE TABLE data_quality_log (
    step_number   INTEGER,
    rule_applied  TEXT,
    rows_affected INTEGER,
    action_taken  TEXT,
    logged_at     TEXT DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------------
-- Step 1: Isolate cancellations into their own table
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS cancelled_transactions;
CREATE TABLE cancelled_transactions AS
SELECT *
FROM raw_transactions
WHERE invoice_no LIKE 'C%';

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 1, 'invoice_no LIKE ''C%''', COUNT(*), 'Moved to cancelled_transactions (excluded from sales analysis)'
FROM raw_transactions WHERE invoice_no LIKE 'C%';

-- ---------------------------------------------------------------------------
-- Step 2: Log rows that will be removed for non-positive quantity/price
-- ---------------------------------------------------------------------------
INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 2, 'quantity <= 0 (and not a cancellation)', COUNT(*), 'Removed'
FROM raw_transactions
WHERE invoice_no NOT LIKE 'C%' AND quantity <= 0;

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 2, 'unit_price <= 0', COUNT(*), 'Removed'
FROM raw_transactions
WHERE invoice_no NOT LIKE 'C%' AND unit_price <= 0;

-- ---------------------------------------------------------------------------
-- Step 3: Build the deduplicated, validated, standardized base table
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS clean_transactions;
CREATE TABLE clean_transactions AS
WITH standardized AS (
    SELECT DISTINCT
        invoice_no,
        stock_code,
        -- collapse repeated whitespace and trim
        TRIM(REPLACE(REPLACE(REPLACE(description, '  ', ' '), '  ', ' '), '  ', ' ')) AS description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        CASE TRIM(country)
            WHEN 'EIRE'      THEN 'Ireland'
            WHEN 'RSA'       THEN 'South Africa'
            WHEN 'USA'       THEN 'United States'
            WHEN 'Unspecified' THEN NULL
            ELSE TRIM(country)
        END AS country
    FROM raw_transactions
    WHERE invoice_no NOT LIKE 'C%'   -- exclude cancellations (Step 1)
      AND quantity > 0               -- exclude non-positive quantity (Step 2)
      AND unit_price > 0             -- exclude non-positive price (Step 2)
),
bounds AS (
    -- IQR bounds for outlier flagging (Step 6), computed on the standardized data
    SELECT
        (SELECT quantity FROM standardized ORDER BY quantity
         LIMIT 1 OFFSET CAST(0.25 * (SELECT COUNT(*) FROM standardized) AS INT))  AS q1_qty,
        (SELECT quantity FROM standardized ORDER BY quantity
         LIMIT 1 OFFSET CAST(0.75 * (SELECT COUNT(*) FROM standardized) AS INT))  AS q3_qty,
        (SELECT unit_price FROM standardized ORDER BY unit_price
         LIMIT 1 OFFSET CAST(0.25 * (SELECT COUNT(*) FROM standardized) AS INT))  AS q1_price,
        (SELECT unit_price FROM standardized ORDER BY unit_price
         LIMIT 1 OFFSET CAST(0.75 * (SELECT COUNT(*) FROM standardized) AS INT))  AS q3_price
)
SELECT
    s.invoice_no,
    s.stock_code,
    s.description,
    s.quantity,
    s.invoice_date,
    s.unit_price,
    s.customer_id,
    s.country,
    CASE WHEN s.customer_id IS NULL THEN 0 ELSE 1 END AS has_customer_id,
    CASE WHEN s.description IS NULL THEN 0 ELSE 1 END AS has_description,
    -- Step 5: administrative / non-product stock codes
    CASE WHEN UPPER(s.stock_code) IN
        ('POST','DOT','M','C2','D','S','BANK CHARGES','AMAZONFEE','CRUK','B')
        THEN 1 ELSE 0 END AS is_adjustment_code,
    -- Step 6: IQR-based outlier flags (flagged, not removed)
    CASE WHEN s.quantity   > (b.q3_qty   + 1.5 * (b.q3_qty   - b.q1_qty))
           OR s.quantity   < (b.q1_qty   - 1.5 * (b.q3_qty   - b.q1_qty))
         THEN 1 ELSE 0 END AS is_outlier_quantity,
    CASE WHEN s.unit_price > (b.q3_price + 1.5 * (b.q3_price - b.q1_price))
           OR s.unit_price < (b.q1_price - 1.5 * (b.q3_price - b.q1_price))
         THEN 1 ELSE 0 END AS is_outlier_price
FROM standardized s
CROSS JOIN bounds b;

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 3, 'Exact duplicate rows', COUNT(*), 'Removed via SELECT DISTINCT'
FROM (
    SELECT invoice_no, stock_code, description, quantity, invoice_date, unit_price, customer_id, country
    FROM raw_transactions
    WHERE invoice_no NOT LIKE 'C%' AND quantity > 0 AND unit_price > 0
    GROUP BY invoice_no, stock_code, description, quantity, invoice_date, unit_price, customer_id, country
    HAVING COUNT(*) > 1
);

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 4, 'Country name standardization (EIRE/RSA/USA/Unspecified)',
       COUNT(*), 'Standardized to full country name'
FROM raw_transactions
WHERE country IN ('EIRE', 'RSA', 'USA', 'Unspecified');

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 5, 'Administrative stock codes (POST, DOT, M, C2, D, S, BANK CHARGES, AMAZONFEE, CRUK, B)',
       COUNT(*), 'Flagged is_adjustment_code = 1 (kept, excluded from product-level views)'
FROM clean_transactions WHERE is_adjustment_code = 1;

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 6, 'IQR outlier bounds on quantity', COUNT(*), 'Flagged is_outlier_quantity = 1 (kept)'
FROM clean_transactions WHERE is_outlier_quantity = 1;

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 6, 'IQR outlier bounds on unit_price', COUNT(*), 'Flagged is_outlier_price = 1 (kept)'
FROM clean_transactions WHERE is_outlier_price = 1;

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 7, 'Missing customer_id', COUNT(*), 'Flagged has_customer_id = 0 (kept, excluded from RFM)'
FROM clean_transactions WHERE has_customer_id = 0;

INSERT INTO data_quality_log (step_number, rule_applied, rows_affected, action_taken)
SELECT 7, 'Missing description', COUNT(*), 'Flagged has_description = 0 (kept)'
FROM clean_transactions WHERE has_description = 0;

-- ---------------------------------------------------------------------------
-- Step 8: Sanity checks + audit trail summary
-- ---------------------------------------------------------------------------
SELECT 'raw_transactions'       AS table_name, COUNT(*) AS row_count FROM raw_transactions
UNION ALL
SELECT 'cancelled_transactions', COUNT(*) FROM cancelled_transactions
UNION ALL
SELECT 'clean_transactions',     COUNT(*) FROM clean_transactions;

SELECT COUNT(*) AS bad_rows
FROM clean_transactions
WHERE quantity <= 0 OR unit_price <= 0;

SELECT MIN(invoice_date) AS min_date, MAX(invoice_date) AS max_date
FROM clean_transactions;

SELECT * FROM data_quality_log ORDER BY step_number;
