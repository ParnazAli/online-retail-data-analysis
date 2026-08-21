/*
===============================================================================
 01_data_cleaning.sql
-------------------------------------------------------------------------------
 Purpose : Clean raw_transactions and produce a trustworthy analytical base
           table (clean_transactions) for all downstream analysis.

 Source  : raw_transactions (541,910 rows, loaded as-is from the original
           Online Retail II source file — see scripts/01_load_raw_data.py)

 Cleaning decisions (each justified, not silently dropped):

   1. Cancelled orders
      Invoices in this dataset that begin with "C" (e.g. "C536379") are
      cancellations/returns, not sales. They are separated into their own
      table so cancellation behaviour can still be analyzed, but they are
      excluded from the main sales analysis (they would otherwise distort
      revenue and quantity totals).

   2. Missing Customer ID
      135,080 rows have no Customer ID. These are kept for country/product
      level analysis, but excluded from all customer-level analysis
      (RFM, customer segmentation) since a customer cannot be identified.

   3. Non-positive price or quantity
      Rows with unit_price <= 0 are typically bank charges, samples,
      adjustments or manual corrections (e.g. "Manual", "POSTAGE", "AMAZON
      FEE" adjustment codes) rather than real product sales, and are
      excluded from revenue-based analysis.

   4. Missing product description
      1,454 rows have a NULL description. Kept, but flagged, since
      stock_code and price are still valid for revenue analysis.

   5. Exact duplicate rows
      Full-row duplicates (same invoice, product, quantity, date, customer)
      are removed — these are data entry duplicates, not repeat purchases
      (a repeat purchase would have a different invoice_no).

 Output tables:
   - clean_transactions      : validated sales rows, ready for analysis
   - cancelled_transactions  : cancellation/return rows, kept separately
===============================================================================
*/

-- ---------------------------------------------------------------------------
-- Step 1: Isolate cancellations into their own table
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS cancelled_transactions;
CREATE TABLE cancelled_transactions AS
SELECT *
FROM raw_transactions
WHERE invoice_no LIKE 'C%';

-- ---------------------------------------------------------------------------
-- Step 2: Build the deduplicated, validated base table
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS clean_transactions;
CREATE TABLE clean_transactions AS
SELECT DISTINCT
    invoice_no,
    stock_code,
    TRIM(description)                       AS description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    CASE WHEN customer_id IS NULL THEN 0 ELSE 1 END AS has_customer_id,
    CASE WHEN description IS NULL THEN 0 ELSE 1 END AS has_description
FROM raw_transactions
WHERE invoice_no NOT LIKE 'C%'      -- exclude cancellations (see Step 1)
  AND quantity > 0                  -- exclude negative/zero quantity rows
  AND unit_price > 0;               -- exclude free/adjustment/fee rows

-- ---------------------------------------------------------------------------
-- Step 3: Sanity checks (run after the above; results documented in README)
-- ---------------------------------------------------------------------------
-- Row counts before/after cleaning
SELECT 'raw_transactions'       AS table_name, COUNT(*) AS row_count FROM raw_transactions
UNION ALL
SELECT 'cancelled_transactions', COUNT(*) FROM cancelled_transactions
UNION ALL
SELECT 'clean_transactions',     COUNT(*) FROM clean_transactions;

-- Confirm no negative quantity/price leaked into the clean table
SELECT COUNT(*) AS bad_rows
FROM clean_transactions
WHERE quantity <= 0 OR unit_price <= 0;

-- Confirm date range makes sense (should be Dec 2010 - Dec 2011)
SELECT MIN(invoice_date) AS min_date, MAX(invoice_date) AS max_date
FROM clean_transactions;
