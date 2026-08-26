"""
03_generate_charts.py
-----------------------
Generates a handful of preview charts (PNG) straight from the SQL views,
for the README and reports/figures. These are a quick look at the results —
the full interactive dashboard is built separately in Power BI using the
exported CSVs in data/processed/.
"""

import sqlite3
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd
import seaborn as sns

sns.set_theme(style="whitegrid", font_scale=1.05)
PALETTE = ["#2C3E50", "#2E86AB", "#54A0FF", "#8395A7", "#C8D6E5"]

DB_PATH = "retail.db"
OUT_DIR = Path("reports/figures")
OUT_DIR.mkdir(parents=True, exist_ok=True)


def monthly_sales_trend(conn):
    df = pd.read_sql_query("SELECT * FROM v_monthly_sales", conn)
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(df["invoice_year_month"], df["total_sales"], marker="o", color=PALETTE[1], linewidth=2.5)
    ax.set_title("Monthly Sales Trend (Dec 2010 \u2013 Dec 2011)", fontsize=14, fontweight="bold", loc="left")
    ax.set_ylabel("Total Sales (\u00a3)")
    ax.set_xlabel("")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"\u00a3{x/1000:.0f}K"))
    plt.xticks(rotation=45, ha="right")
    sns.despine()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "monthly_sales_trend.png", dpi=160)
    plt.close(fig)


def sales_by_segment(conn):
    df = pd.read_sql_query("SELECT * FROM v_sales_contribution_by_segment", conn)
    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(df["customer_segment"], df["total_sales"], color=PALETTE[: len(df)])
    ax.set_title("Revenue Contribution by Customer Segment (RFM)", fontsize=14, fontweight="bold", loc="left")
    ax.set_ylabel("Total Revenue (\u00a3)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"\u00a3{x/1e6:.1f}M"))
    for b in bars:
        h = b.get_height()
        ax.annotate(f"\u00a3{h/1e6:.2f}M", (b.get_x() + b.get_width() / 2, h),
                    ha="center", va="bottom", fontsize=9)
    sns.despine()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "sales_by_segment.png", dpi=160)
    plt.close(fig)


def top_10_products(conn):
    df = pd.read_sql_query("SELECT * FROM v_top_10_products ORDER BY total_quantity ASC", conn)
    fig, ax = plt.subplots(figsize=(9, 6))
    ax.barh(df["product"].str.title(), df["total_quantity"], color=PALETTE[1])
    ax.set_title("Top 10 Products by Quantity Sold", fontsize=14, fontweight="bold", loc="left")
    ax.set_xlabel("Units Sold")
    sns.despine()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "top_10_products.png", dpi=160)
    plt.close(fig)


def peak_hours(conn):
    df = pd.read_sql_query("SELECT * FROM v_peak_hours", conn)
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.bar(df["invoice_hour"], df["total_orders"], color=PALETTE[1])
    ax.set_title("Orders by Hour of Day", fontsize=14, fontweight="bold", loc="left")
    ax.set_xlabel("Hour (24h)")
    ax.set_ylabel("Number of Orders")
    ax.set_xticks(df["invoice_hour"])
    sns.despine()
    fig.tight_layout()
    fig.savefig(OUT_DIR / "peak_hours.png", dpi=160)
    plt.close(fig)


def customer_distribution(conn):
    df = pd.read_sql_query("SELECT * FROM v_customer_distribution", conn)
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.pie(
        df["num_customers"],
        labels=df["customer_segment"],
        autopct="%1.0f%%",
        colors=PALETTE[: len(df)],
        startangle=90,
        wedgeprops={"edgecolor": "white", "linewidth": 1.5},
    )
    ax.set_title("Customer Distribution by RFM Segment", fontsize=14, fontweight="bold")
    fig.tight_layout()
    fig.savefig(OUT_DIR / "customer_distribution.png", dpi=160)
    plt.close(fig)


def main():
    conn = sqlite3.connect(DB_PATH)
    monthly_sales_trend(conn)
    sales_by_segment(conn)
    top_10_products(conn)
    peak_hours(conn)
    customer_distribution(conn)
    conn.close()
    print(f"Charts written to {OUT_DIR}/")


if __name__ == "__main__":
    main()
