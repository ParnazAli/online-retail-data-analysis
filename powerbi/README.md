# Power BI Dashboard — Build Notes

The SQL layer produces two clean, analysis-ready CSVs:

- `data/processed/fact_transactions.csv` — one row per order line
- `data/processed/dim_customer_rfm.csv` — one row per customer, with RFM scores and segment

## Setup

1. **Get Data → Text/CSV** — import both files.
2. **Model view** — create a relationship:
   `fact_transactions[customer_id]` → `dim_customer_rfm[customer_id]`
   (Many-to-one, single direction, from fact to dimension.)
3. Set `invoice_date` to Date/Time type, `total_price` / `monetary` to
   Fixed Decimal Number (currency format, £).

## Suggested pages / visuals

| Page | Visuals |
|---|---|
| **Overview** | KPI cards (Total Revenue, Total Orders, Total Customers, AOV), Monthly Sales Trend (line), Top 5 Countries (bar map) |
| **Customers (RFM)** | Customer Distribution by Segment (donut), Revenue by Segment (bar), RFM scatter (Recency vs Monetary, sized by Frequency) |
| **Products** | Top 10 Products by Quantity (bar), Top 10 Products by Revenue (bar) |
| **Operations** | Orders by Hour (bar), Order Distribution by Time-of-Day Bucket (donut) |

## Filters / slicers

- Date range (`invoice_date`)
- Country
- Customer segment (`customer_segment`)

## Once built

Export the `.pbix` file and drop it in this folder, plus a screenshot
(`dashboard_preview.png`) to embed in the main README.
