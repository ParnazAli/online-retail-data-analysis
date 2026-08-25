"""
02_export_for_powerbi.py
-------------------------
Exports the final, SQL-cleaned tables to CSV so they can be imported directly
into Power BI (Get Data > Text/CSV) and related on customer_id.

Exports:
  data/processed/fact_transactions.csv   - one row per order line (fact table)
  data/processed/dim_customer_rfm.csv    - one row per customer (dimension table)
  data/processed/cancelled_transactions.csv - cancellations, kept separately

In Power BI:
  1. Import both CSVs.
  2. Create a relationship: fact_transactions[customer_id] -> dim_customer_rfm[customer_id]
     (many-to-one, single direction).
  3. Build visuals directly from these — all cleaning/scoring is already done.
"""

import sqlite3
from pathlib import Path

import pandas as pd

DB_PATH = "retail.db"
OUT_DIR = Path("data/processed")


def export_table(conn, table_or_view: str, out_name: str):
    df = pd.read_sql_query(f"SELECT * FROM {table_or_view}", conn)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / out_name
    df.to_csv(out_path, index=False)
    print(f"{table_or_view:30s} -> {out_path}  ({len(df):,} rows)")


def main():
    conn = sqlite3.connect(DB_PATH)
    export_table(conn, "transactions_enriched", "fact_transactions.csv")
    export_table(conn, "customer_rfm", "dim_customer_rfm.csv")
    export_table(conn, "cancelled_transactions", "cancelled_transactions.csv")
    conn.close()


if __name__ == "__main__":
    main()
