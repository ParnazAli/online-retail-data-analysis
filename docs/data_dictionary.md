# Data Dictionary

## `data/raw/online_retail_II_RAW.xlsb` (source, untouched)

| Column | Type | Description |
|---|---|---|
| Invoice | text | Invoice number. Prefixed `C` = cancellation. |
| StockCode | text | Product/item code. |
| Description | text | Product name. |
| Quantity | integer | Units purchased (negative = return). |
| InvoiceDate | datetime | Date and time of the transaction. |
| Price | decimal | Unit price in GBP (£). |
| Customer ID | integer | Unique customer identifier (nullable — guest checkout). |
| Country | text | Customer's country. |

## `fact_transactions.csv` (Power BI fact table)

Output of `sql/02_feature_engineering.sql`, built on cleaned data.

| Column | Description |
|---|---|
| invoice_no | Invoice number |
| stock_code | Product code |
| description | Product name |
| quantity | Units purchased |
| unit_price | Price per unit (£) |
| total_price | `quantity * unit_price` |
| invoice_date | Full timestamp |
| invoice_year / invoice_month / invoice_year_month | Calendar parts |
| invoice_day_name | Day of week |
| invoice_hour | Hour of day (0–23) |
| time_of_day_bucket | One of: 6 AM–9 AM, 10 AM–1 PM, 2 PM–5 PM, 6 PM–9 PM |
| customer_id | Customer identifier (null for guest orders) |
| country | Customer's country (standardized: EIRE→Ireland, RSA→South Africa, USA→United States) |
| has_customer_id / has_description | Data-quality flags |
| is_adjustment_code | 1 if stock_code is administrative (POST, DOT, M, C2, D, S, BANK CHARGES, AMAZONFEE, CRUK, B), not a real product |
| is_outlier_quantity / is_outlier_price | 1 if flagged by the IQR method — kept, not removed, since a large wholesale order is valid data |

## `data_quality_log` (audit trail)

Every cleaning rule applied in `sql/01_data_cleaning.sql`, logged with the
rule, rows affected, and the action taken. Nothing is silently dropped.

## `dim_customer_rfm.csv` (Power BI dimension table)

Output of `sql/03_rfm_analysis.sql`. One row per identified customer.

| Column | Description |
|---|---|
| customer_id | Customer identifier — join key to `fact_transactions` |
| recency_days | Days since last purchase (relative to day after last dataset date) |
| frequency | Number of distinct invoices |
| monetary | Total revenue from this customer (£) |
| recency_score / frequency_score / monetary_score | 1–5 quintile scores |
| rfm_total_score | Sum of the three scores (3–15) |
| customer_segment | VIP / Frequent Buyer / Active / At Risk / Regular |

## `cancelled_transactions.csv`

Raw cancellation rows (`Invoice` starting with `C`), kept separately from
the main fact table. Useful for a returns-analysis extension.
