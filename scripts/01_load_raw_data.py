"""
01_load_raw_data.py
--------------------
Loads the original 'Online Retail II' raw file (.xlsb) and writes it, untouched,
into:
  1) data/raw/online_retail_raw.csv   (flat file backup of the raw source)
  2) retail.db (SQLite)                (raw_transactions table)

IMPORTANT: This script does NOT clean or filter any data. It only reads the
source file and converts data types that are strictly a format issue
(e.g. Excel's numeric date serial -> proper datetime). All business/data
cleaning logic (nulls, cancellations, duplicates, invalid values, feature
engineering, RFM, aggregations) lives in the SQL scripts under /sql,
which is the actual deliverable of this project.

Usage:
    python scripts/01_load_raw_data.py --source data/raw/online_retail_II_RAW.xlsb
"""

import argparse
import sqlite3
from pathlib import Path

import pandas as pd

RAW_COLUMNS = {
    "Invoice": "invoice_no",
    "StockCode": "stock_code",
    "Description": "description",
    "Quantity": "quantity",
    "InvoiceDate": "invoice_date",
    "Price": "unit_price",
    "Customer ID": "customer_id",
    "Country": "country",
}


def load_raw(source_path: Path) -> pd.DataFrame:
    df = pd.read_excel(source_path, engine="pyxlsb", sheet_name="Year 2010-2011")
    df = df.rename(columns=RAW_COLUMNS)

    # Excel/xlsb stores dates as a numeric serial (days since 1899-12-30).
    # Converting this is a *format* fix, not a data cleaning decision.
    df["invoice_date"] = pd.to_datetime(
        df["invoice_date"], unit="D", origin="1899-12-30"
    )

    return df[list(RAW_COLUMNS.values())]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, help="Path to the raw .xlsb file")
    parser.add_argument("--db", default="retail.db", help="Path to output SQLite DB")
    parser.add_argument(
        "--csv-out", default="data/raw/online_retail_raw.csv", help="Raw CSV backup path"
    )
    args = parser.parse_args()

    df = load_raw(Path(args.source))
    print(f"Loaded {len(df):,} raw rows, {df.shape[1]} columns")

    Path(args.csv_out).parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(args.csv_out, index=False)
    print(f"Raw CSV written to {args.csv_out}")

    conn = sqlite3.connect(args.db)
    df.to_sql("raw_transactions", conn, if_exists="replace", index=False)
    conn.close()
    print(f"raw_transactions table written to {args.db}")


if __name__ == "__main__":
    main()
