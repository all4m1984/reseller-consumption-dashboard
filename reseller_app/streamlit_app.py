import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session
from datetime import datetime, timedelta

st.set_page_config(page_title="Reseller Billing — Partner Portal", layout="wide",
    page_icon="https://upload.wikimedia.org/wikipedia/commons/f/ff/Snowflake_Logo.svg")

SNOWFLAKE_LOGO = "https://upload.wikimedia.org/wikipedia/commons/f/ff/Snowflake_Logo.svg"

SF_BLUE = "#29B5E8"
SF_DARK_BLUE = "#11567F"
SF_LIGHT_BLUE = "#E8F4FA"
SF_NAVY = "#0D2137"
SF_GRAY = "#6E7681"
SF_LIGHT_GRAY = "#F0F2F5"
SF_ORANGE = "#FF6B35"
SF_GREEN = "#2ECC71"
SF_RED = "#E74C3C"

COLOR_MAP = {
    "WAREHOUSE_METERING": SF_BLUE, "CLOUD_SERVICES": "#5B9BD5", "STORAGE": SF_ORANGE,
    "AUTOMATIC_CLUSTERING": "#A5D6A7", "SERVERLESS_TASK": "#CE93D8",
    "SNOWPIPE": "#FFD54F", "DATA_TRANSFER": "#EF9A9A"
}
USAGE_COLOR_MAP = {
    "compute": SF_BLUE, "cloud services": "#5B9BD5", "storage": SF_ORANGE,
    "automatic clustering": "#A5D6A7", "serverless tasks": "#CE93D8",
    "snowpipe": "#FFD54F", "data transfer": "#EF9A9A"
}

st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    * { font-family: 'Inter', sans-serif !important; }
    .main .block-container { padding-top: 1.5rem; max-width: 1400px; }
    .stTabs [data-baseweb="tab-list"] { gap: 0px; border-bottom: 2px solid #E8F4FA; }
    .stTabs [data-baseweb="tab"] {
        padding: 8px 24px; font-weight: 500; color: #6E7681;
        border: none; background: transparent;
    }
    .stTabs [aria-selected="true"] {
        color: #11567F; border-bottom: 3px solid #29B5E8;
        font-weight: 600; background: transparent;
    }
    .stDownloadButton > button {
        background: transparent; color: #29B5E8; border: 1px solid #29B5E8;
        font-size: 0.8rem; padding: 4px 12px;
    }
    .stDownloadButton > button:hover { background: #E8F4FA; }
    div[data-testid="stDataFrame"] th {
        background-color: #29B5E8 !important; color: white !important;
        font-weight: 600 !important; font-size: 0.8rem !important;
    }
    div[data-testid="stDataFrame"] td { font-size: 0.8rem !important; }
</style>
""", unsafe_allow_html=True)

PLOTLY_CONFIG = {"displayModeBar": True, "staticPlot": False, "scrollZoom": False}
PLOTLY_LAYOUT = dict(
    plot_bgcolor="white", paper_bgcolor="white",
    font=dict(family="Inter", size=11, color=SF_NAVY),
    margin=dict(l=50, r=20, t=30, b=40),
    legend=dict(orientation="h", yanchor="bottom", y=-0.25, xanchor="center", x=0.5, font=dict(size=9)),
    yaxis=dict(gridcolor="#F0F2F5", zeroline=False),
    xaxis=dict(gridcolor="#F0F2F5", zeroline=False)
)


def kpi_card(title, value, subtitle="", delta_text="", delta_color=SF_GRAY, border_top_color=SF_BLUE):
    return f"""
    <div style="background:white; border-radius:8px; padding:14px 16px; border-top:3px solid {border_top_color};
        box-shadow:0 1px 4px rgba(0,0,0,0.06); min-height:130px;">
        <div style="font-size:0.68rem; font-weight:600; color:{SF_GRAY}; text-transform:uppercase; letter-spacing:0.5px;
            margin-bottom:6px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">{title}</div>
        <div style="font-size:1.5rem; font-weight:700; color:{SF_NAVY}; margin-bottom:6px; line-height:1.2;">{value}</div>
        <div style="font-size:0.65rem; color:{delta_color}; line-height:1.3; margin-bottom:3px;">{delta_text}</div>
        <div style="font-size:0.62rem; color:{SF_GRAY}; line-height:1.3;">{subtitle}</div>
    </div>
    """


def section_header(text):
    st.markdown(
        f'<h3 style="color:{SF_NAVY}; font-weight:600; font-size:1.1rem; margin:20px 0 12px 0; '
        f'border-bottom:2px solid {SF_LIGHT_BLUE}; padding-bottom:8px;">{text}</h3>',
        unsafe_allow_html=True)


def fmt_currency(val, prefix="$"):
    if val is None:
        return f"{prefix}0"
    if abs(val) >= 1_000_000:
        return f"{prefix}{val / 1_000_000:,.1f}M"
    if abs(val) >= 1_000:
        return f"{prefix}{val:,.0f}"
    return f"{prefix}{val:,.2f}"


def fmt_pct(val):
    if val is None:
        return "0.0%"
    return f"{val:.1f}%"


@st.cache_data(ttl=3600)
def load_reseller_data():
    session = get_active_session()
    db = "RESELLER_BILLING_FINAL"
    contracts = session.sql(f"SELECT * FROM {db}.BILLING.PARTNER_CONTRACT_ITEMS").to_pandas()
    usage = session.sql(f"SELECT * FROM {db}.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY").to_pandas()
    balance = session.sql(f"SELECT * FROM {db}.BILLING.PARTNER_REMAINING_BALANCE_DAILY").to_pandas()
    rates = session.sql(f"SELECT * FROM {db}.BILLING.PARTNER_RATE_SHEET_DAILY").to_pandas()
    markup = session.sql(f"""
        SELECT m.SOLD_TO_ORGANIZATION_NAME, a.SOLD_TO_CUSTOMER_NAME, m.MARKUP_PCT,
               a.CONSUMER_ACCOUNT_LOCATOR, a.IS_ACTIVE
        FROM {db}.SHARING_CONFIG.MARKUP_RATES m
        JOIN {db}.SHARING_CONFIG.ACCOUNT_MAPPING a
            ON m.SOLD_TO_ORGANIZATION_NAME = a.SOLD_TO_ORGANIZATION_NAME
        WHERE m.IS_ACTIVE = TRUE AND (m.EFFECTIVE_TO IS NULL OR m.EFFECTIVE_TO >= CURRENT_DATE())
    """).to_pandas()
    for df in [usage, balance, rates]:
        for c in [col for col in df.columns if "DATE" in col.upper() or col.upper() == "DATE"]:
            df[c] = pd.to_datetime(df[c])
    for c in contracts.columns:
        if "DATE" in c.upper():
            contracts[c] = pd.to_datetime(contracts[c])
    return contracts, usage, balance, rates, markup


contracts, usage, balance, rates, markup = load_reseller_data()

customers = sorted(usage["SOLD_TO_CUSTOMER_NAME"].unique().tolist())
total_customers = len(customers)
total_consumption_all = float(usage["USAGE_IN_CURRENCY"].sum())
total_credits_all = float(usage["USAGE"].sum())

total_capacity_all = float(contracts[contracts["CONTRACT_ITEM"] == "capacity"]["AMOUNT"].sum())
total_free_all = float(contracts[contracts["CONTRACT_ITEM"] == "free usage"]["AMOUNT"].sum())

latest_balances = balance.sort_values("DATE", ascending=False).drop_duplicates("SOLD_TO_CONTRACT_NUMBER")
total_remaining_all = float(latest_balances["CAPACITY_BALANCE"].sum())
total_overage_all = float(latest_balances["ON_DEMAND_CONSUMPTION_BALANCE"].apply(lambda x: abs(x) if x < 0 else 0).sum())

markup_revenue = 0
for _, m in markup.iterrows():
    cust_usage = float(usage[usage["SOLD_TO_ORGANIZATION_NAME"] == m["SOLD_TO_ORGANIZATION_NAME"]]["USAGE_IN_CURRENCY"].sum())
    markup_revenue += cust_usage * float(m["MARKUP_PCT"])

st.markdown(f"""
<div style="display:flex; align-items:center; gap:14px; padding:12px 0 16px 0; border-bottom:2px solid {SF_LIGHT_BLUE}; margin-bottom:16px;">
    <img src="{SNOWFLAKE_LOGO}" alt="Snowflake" style="height:40px; width:auto;">
    <div>
        <div style="font-size:1.4rem; font-weight:700; color:{SF_NAVY}; letter-spacing:-0.3px;">Reseller Partner Portal — Billing Overview</div>
        <div style="font-size:0.78rem; color:{SF_GRAY}; margin-top:2px;">Raw billing data across all customers (pre-markup)</div>
    </div>
</div>
""", unsafe_allow_html=True)

k1, k2, k3, k4, k5, k6 = st.columns(6)

avg_markup_pct = float(markup["MARKUP_PCT"].mean()) if len(markup) > 0 else 0

with k1:
    st.markdown(kpi_card("Total Customers", str(total_customers),
        f"{usage['ACCOUNT_NAME'].nunique()} accounts",
        f"Active contracts: {contracts['SOLD_TO_CONTRACT_NUMBER'].nunique()}",
        SF_BLUE, SF_BLUE), unsafe_allow_html=True)
with k2:
    st.markdown(kpi_card("Total Consumption", fmt_currency(total_consumption_all),
        f"Customer sees: {fmt_currency(total_consumption_all + markup_revenue)}",
        f"Credits: {total_credits_all:,.0f}",
        SF_GRAY, SF_DARK_BLUE), unsafe_allow_html=True)
with k3:
    marked_remaining = total_remaining_all * (1 + avg_markup_pct)
    st.markdown(kpi_card("Remaining Balance", fmt_currency(total_remaining_all),
        f"Customer sees: ~{fmt_currency(marked_remaining)}",
        f"{fmt_pct((total_remaining_all / total_capacity_all * 100) if total_capacity_all > 0 else 0)} of capacity remaining",
        SF_GRAY, SF_GREEN), unsafe_allow_html=True)
with k4:
    marked_overage = total_overage_all * (1 + avg_markup_pct)
    st.markdown(kpi_card("Total Overage", fmt_currency(total_overage_all),
        f"Customer sees: ~{fmt_currency(marked_overage)}" if total_overage_all > 0 else "No overage",
        f"{int((latest_balances['ON_DEMAND_CONSUMPTION_BALANCE'] < 0).sum())} customers in overage",
        SF_RED if total_overage_all > 0 else SF_GREEN,
        SF_RED if total_overage_all > 0 else SF_GREEN), unsafe_allow_html=True)
with k5:
    st.markdown(kpi_card("Markup Revenue", fmt_currency(markup_revenue),
        f"Total billed to customers: {fmt_currency(total_consumption_all + markup_revenue)}",
        f"Avg markup: {fmt_pct(avg_markup_pct * 100)}",
        SF_GREEN, SF_ORANGE), unsafe_allow_html=True)
with k6:
    at_risk = 0
    expired_count = 0
    for cust_name in customers:
        cc = contracts[contracts["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        cb = latest_balances[latest_balances["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        cu = usage[usage["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        c_end = cc["END_DATE"].max() if len(cc) > 0 else None
        if c_end is not None and pd.Timestamp.now() > c_end:
            expired_count += 1
            continue
        if len(cb) > 0 and len(cu) > 0:
            r = float(cb["CAPACITY_BALANCE"].iloc[0]) + float(cb["ROLLOVER_BALANCE"].iloc[0]) + float(cb["FREE_USAGE_BALANCE"].iloc[0])
            l30 = cu[cu["USAGE_DATE"] >= (pd.Timestamp.now() - timedelta(days=30))]
            l30_daily = l30.groupby("USAGE_DATE")["USAGE_IN_CURRENCY"].sum()
            db2 = float(l30_daily.mean()) if len(l30_daily) > 0 else 0
            if db2 > 0 and r / db2 < 60:
                at_risk += 1
    st.markdown(kpi_card("At-Risk Customers", str(at_risk),
        f"{expired_count} expired contracts",
        "Depletes within 60 days (30d burn)",
        SF_RED if at_risk > 0 else SF_GREEN,
        SF_RED if at_risk > 0 else SF_GREEN), unsafe_allow_html=True)

tab_portfolio, tab_customer, tab_comparison, tab_margins = st.tabs(
    ["Portfolio Overview", "Customer Deep Dive", "Customer Comparison", "Markup & Margins"])

with tab_portfolio:
    section_header("Monthly Consumption by Customer")

    usage_monthly = usage.copy()
    usage_monthly["MONTH"] = usage_monthly["USAGE_DATE"].dt.to_period("M").dt.to_timestamp()
    monthly_by_cust = usage_monthly.groupby(["MONTH", "SOLD_TO_CUSTOMER_NAME"])["USAGE_IN_CURRENCY"].sum().reset_index()

    fig1 = px.bar(monthly_by_cust, x="MONTH", y="USAGE_IN_CURRENCY", color="SOLD_TO_CUSTOMER_NAME",
        barmode="stack", labels={"USAGE_IN_CURRENCY": "USD ($)", "MONTH": "", "SOLD_TO_CUSTOMER_NAME": ""})
    fig1.update_layout(**{**PLOTLY_LAYOUT, "height": 400, "yaxis_tickformat": "$,.0f", "xaxis_tickformat": "%b %Y"})
    st.plotly_chart(fig1, use_container_width=True, config=PLOTLY_CONFIG)

    section_header("Customer Summary Table")

    cust_summary = []
    for cust_name in customers:
        cust_contracts = contracts[contracts["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        cust_usage = usage[usage["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        cust_bal = latest_balances[latest_balances["SOLD_TO_CUSTOMER_NAME"] == cust_name]

        cap = float(cust_contracts[cust_contracts["CONTRACT_ITEM"] == "capacity"]["AMOUNT"].sum())
        consumed = float(cust_usage["USAGE_IN_CURRENCY"].sum())
        remaining = float(cust_bal["CAPACITY_BALANCE"].sum()) if len(cust_bal) > 0 else 0
        roll_b = float(cust_bal["ROLLOVER_BALANCE"].sum()) if len(cust_bal) > 0 else 0
        free_b = float(cust_bal["FREE_USAGE_BALANCE"].sum()) if len(cust_bal) > 0 else 0
        ovg = float(cust_bal["ON_DEMAND_CONSUMPTION_BALANCE"].apply(lambda x: abs(x) if x < 0 else 0).sum()) if len(cust_bal) > 0 else 0
        if ovg == 0 and consumed > cap and remaining <= 0:
            ovg = consumed - cap
        total_funds = remaining + roll_b + free_b

        last30 = cust_usage[cust_usage["USAGE_DATE"] >= (pd.Timestamp.now() - timedelta(days=30))]
        last30_daily = last30.groupby("USAGE_DATE")["USAGE_IN_CURRENCY"].sum()
        burn = float(last30_daily.mean()) if len(last30_daily) > 0 else 0
        days_left = int(total_funds / burn) if burn > 0 and total_funds > 0 else 999 if total_funds > 0 else 0

        m = markup[markup["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        mp = float(m["MARKUP_PCT"].iloc[0]) * 100 if len(m) > 0 else 0

        end_d = cust_contracts["END_DATE"].max() if len(cust_contracts) > 0 else None
        status = "Expired" if end_d is not None and pd.Timestamp.now() > end_d else "At Risk" if days_left < 60 else "Active"

        cust_summary.append({
            "Customer": cust_name,
            "Capacity ($)": cap, "Consumed ($)": consumed,
            "Remaining ($)": remaining, "Overage ($)": ovg,
            "Burn Rate ($/day)": round(burn, 2),
            "Days to Depletion": days_left if days_left < 999 else "N/A",
            "Markup (%)": mp, "Status": status
        })

    df_summary = pd.DataFrame(cust_summary).sort_values("Consumed ($)", ascending=False)
    st.dataframe(df_summary, hide_index=True, use_container_width=True)
    st.download_button("Download customer summary as CSV", df_summary.to_csv(index=False),
        "reseller_customer_summary.csv", "text/csv", key="dl_summary")

with tab_customer:
    section_header("Customer Deep Dive")

    selected_customer = st.selectbox("Select Customer", customers, key="deep_dive_cust")

    cust_usage = usage[usage["SOLD_TO_CUSTOMER_NAME"] == selected_customer]
    cust_contracts = contracts[contracts["SOLD_TO_CUSTOMER_NAME"] == selected_customer]
    cust_bal = balance[balance["SOLD_TO_CUSTOMER_NAME"] == selected_customer]

    cap = float(cust_contracts[cust_contracts["CONTRACT_ITEM"] == "capacity"]["AMOUNT"].sum())
    free_u = float(cust_contracts[cust_contracts["CONTRACT_ITEM"] == "free usage"]["AMOUNT"].sum())
    consumed = float(cust_usage["USAGE_IN_CURRENCY"].sum())

    cust_latest = cust_bal.sort_values("DATE", ascending=False).head(1)
    rem = float(cust_latest["CAPACITY_BALANCE"].iloc[0]) if len(cust_latest) > 0 else 0
    roll = float(cust_latest["ROLLOVER_BALANCE"].iloc[0]) if len(cust_latest) > 0 else 0
    rem_free = float(cust_latest["FREE_USAGE_BALANCE"].iloc[0]) if len(cust_latest) > 0 else 0
    cust_on_demand = float(cust_latest["ON_DEMAND_CONSUMPTION_BALANCE"].iloc[0]) if len(cust_latest) > 0 else 0
    cust_overage = abs(cust_on_demand) if cust_on_demand < 0 else 0
    if cust_overage == 0 and consumed > (cap + free_u) and rem <= 0:
        cust_overage = consumed - cap - free_u
    cust_entitlement = cap + free_u
    cust_consumption_pct = (consumed / cust_entitlement * 100) if cust_entitlement > 0 else 0
    total_remaining_cust = rem + roll + rem_free

    last30 = cust_usage[cust_usage["USAGE_DATE"] >= (pd.Timestamp.now() - timedelta(days=30))]
    last30_daily = last30.groupby("USAGE_DATE")["USAGE_IN_CURRENCY"].sum()
    burn = float(last30_daily.mean()) if len(last30_daily) > 0 else 0
    days_left = int(total_remaining_cust / burn) if burn > 0 and total_remaining_cust > 0 else 0 if total_remaining_cust <= 0 else 999

    cust_end = cust_contracts["END_DATE"].max() if len(cust_contracts) > 0 else None
    cust_start = cust_contracts["START_DATE"].min() if len(cust_contracts) > 0 else None
    cust_expired = cust_end is not None and pd.Timestamp.now() > cust_end
    cust_raw_days = (cust_end - pd.Timestamp.now()).days if cust_end else 0
    cust_days_to_expiry = max(cust_raw_days, 0)
    cust_depleted = rem <= 0 or cust_overage > 0

    cust_daily = cust_usage.groupby("USAGE_DATE")["USAGE_IN_CURRENCY"].sum().reset_index().sort_values("USAGE_DATE")
    cust_daily["CUMULATIVE"] = cust_daily["USAGE_IN_CURRENCY"].cumsum()

    if cust_depleted:
        days_left = 0
        crossed = cust_daily[cust_daily["CUMULATIVE"] >= cust_entitlement]
        depletion_date_cust = crossed["USAGE_DATE"].iloc[0].strftime("%Y-%m-%d") if len(crossed) > 0 else "Depleted"
    elif burn > 0 and total_remaining_cust > 0:
        days_left = int(total_remaining_cust / burn)
        depletion_date_cust = (pd.Timestamp.now() + timedelta(days=days_left)).strftime("%Y-%m-%d")
    else:
        days_left = 999
        depletion_date_cust = "N/A"

    depl_before_exp = not cust_expired and not cust_depleted and days_left < cust_days_to_expiry
    depl_color = SF_RED if cust_depleted or days_left < 60 else SF_ORANGE if days_left < 120 else SF_GREEN

    m = markup[markup["SOLD_TO_CUSTOMER_NAME"] == selected_customer]
    mp = float(m["MARKUP_PCT"].iloc[0]) * 100 if len(m) > 0 else 0
    margin_rev = consumed * (mp / 100)

    r1c1, r1c2, r1c3, r1c4, r1c5, r1c6, r1c7 = st.columns(7)
    with r1c1:
        st.markdown(kpi_card("Total Consumption", fmt_currency(consumed),
            f"Customer sees: {fmt_currency(consumed + margin_rev)}",
            f"▲ {fmt_pct(cust_consumption_pct)} of entitlement ({fmt_currency(cust_entitlement)})",
            SF_BLUE, SF_BLUE), unsafe_allow_html=True)
    with r1c2:
        cust_credits = float(cust_usage["USAGE"].sum())
        st.markdown(kpi_card("Total Credits",
            fmt_currency(cust_credits, prefix=""),
            f"Across {cust_usage['USAGE_DATE'].nunique()} days",
            f"Avg {cust_credits / max(cust_usage['USAGE_DATE'].nunique(), 1):,.1f}/day",
            SF_GRAY, SF_DARK_BLUE), unsafe_allow_html=True)
    with r1c3:
        marked_ovg = cust_overage * (1 + mp / 100)
        st.markdown(kpi_card("Overage", fmt_currency(cust_overage),
            f"Customer sees: {fmt_currency(marked_ovg)}" if cust_overage > 0 else "No overage",
            f"Rollover: {fmt_currency(roll)}",
            SF_RED if cust_overage > 0 else SF_GREEN, SF_RED if cust_overage > 0 else SF_GREEN), unsafe_allow_html=True)
    with r1c4:
        marked_rem = rem * (1 + mp / 100)
        bc = SF_RED if rem <= 0 else SF_ORANGE if cust_consumption_pct > 80 else SF_GREEN
        st.markdown(kpi_card("Remaining Balance", fmt_currency(rem),
            f"Customer sees: {fmt_currency(marked_rem)}",
            f"Free: {fmt_currency(rem_free)} · Roll: {fmt_currency(roll)}",
            SF_GRAY, bc), unsafe_allow_html=True)
    with r1c5:
        if cust_expired:
            el, ed, eb = "EXPIRED", f"Ended {abs(cust_raw_days)} days ago", SF_RED
        elif cust_days_to_expiry == 0:
            el, ed, eb = "TODAY", "Expires today", SF_RED
        elif cust_days_to_expiry < 30:
            el, ed, eb = f"{cust_days_to_expiry} days", "⚠ Expiring soon", SF_RED
        elif cust_days_to_expiry < 60:
            el, ed, eb = f"{cust_days_to_expiry} days", "⚠ Approaching", SF_ORANGE
        else:
            el, ed, eb = f"{cust_days_to_expiry} days", "", SF_BLUE
        st.markdown(kpi_card("Days Until Expiry", el,
            f"Expiry: {cust_end.strftime('%Y-%m-%d') if cust_end else 'N/A'}", ed,
            SF_RED if cust_expired or cust_days_to_expiry < 30 else SF_GRAY, eb), unsafe_allow_html=True)
    with r1c6:
        if cust_depleted:
            dl, dw, ds2 = "DEPLETED", f"⚠ Exhausted on {depletion_date_cust}", f"Funds: {fmt_currency(total_remaining_cust)}"
            db = SF_RED
        elif cust_expired:
            dl, dw, ds2 = f"{days_left} days" if days_left < 999 else "N/A", "Contract expired", f"Funds: {fmt_currency(total_remaining_cust)}"
            db = SF_ORANGE
        elif depl_before_exp:
            dl, dw, ds2 = f"{days_left} days", f"⚠ ~{depletion_date_cust}", f"Remaining: {fmt_currency(total_remaining_cust)} at {fmt_currency(burn)}/day"
            db = SF_RED
        else:
            dl = f"{days_left} days" if days_left < 999 else "N/A"
            dw, ds2 = "✓ Sufficient", f"Remaining: {fmt_currency(total_remaining_cust)} at {fmt_currency(burn)}/day"
            db = SF_GREEN
        st.markdown(kpi_card("Days to Depletion", dl, ds2, dw, depl_color, db), unsafe_allow_html=True)
    with r1c7:
        st.markdown(kpi_card("Markup", f"{mp:.1f}%",
            f"Margin: {fmt_currency(margin_rev)}",
            f"Customer sees: {fmt_currency(consumed + margin_rev)}",
            SF_GRAY, SF_ORANGE), unsafe_allow_html=True)

    if cust_depleted:
        st.markdown(f"""<div style="background:#FFEBEE; border-left:4px solid {SF_RED}; padding:12px 16px; border-radius:4px; margin:8px 0; font-size:0.82rem;">
            <strong style="color:{SF_RED};">⚠ Capacity Depleted:</strong>
            <span style="color:{SF_NAVY};"> {selected_customer}'s capacity of <strong>{fmt_currency(cap)}</strong> exhausted on <strong>{depletion_date_cust}</strong>.
            Consumption: <strong>{fmt_currency(consumed)}</strong>. Rollover: <strong>{fmt_currency(roll)}</strong>. Contact customer for top-up.</span>
        </div>""", unsafe_allow_html=True)
    elif depl_before_exp:
        st.markdown(f"""<div style="background:#FFF3E0; border-left:4px solid {SF_ORANGE}; padding:12px 16px; border-radius:4px; margin:8px 0; font-size:0.82rem;">
            <strong style="color:{SF_ORANGE};">⚠ Top-Up Advisory:</strong>
            <span style="color:{SF_NAVY};"> At <strong>{fmt_currency(burn)}/day</strong>, {selected_customer}'s balance of <strong>{fmt_currency(total_remaining_cust)}</strong> (cap+rollover+free) depletes by
            <strong>{depletion_date_cust}</strong> — <strong>{cust_days_to_expiry - days_left} days before</strong> contract ends.</span>
        </div>""", unsafe_allow_html=True)
    if cust_expired:
        st.markdown(f"""<div style="background:#FFEBEE; border-left:4px solid {SF_RED}; padding:12px 16px; border-radius:4px; margin:8px 0; font-size:0.82rem;">
            <strong style="color:{SF_RED};">⚠ Contract Expired:</strong>
            <span style="color:{SF_NAVY};"> {selected_customer}'s contract ended <strong>{cust_end.strftime('%Y-%m-%d') if cust_end else 'N/A'}</strong> ({abs(cust_raw_days)} days ago). Initiate renewal.</span>
        </div>""", unsafe_allow_html=True)

    markup_mult = 1 + (mp / 100)
    st.markdown(f"""<div style="font-size:0.68rem; color:{SF_NAVY}; margin:10px 0 2px 0; padding:6px 10px;
        background:{SF_LIGHT_BLUE}; border-radius:4px; border-left:3px solid {SF_BLUE};">
        <strong>Reseller View (Raw):</strong>&nbsp;
        Entitlement={fmt_currency(cust_entitlement)} · Capacity={fmt_currency(cap)} ·
        Free={fmt_currency(free_u)} · Rollover={fmt_currency(roll)} ·
        Consumed={fmt_currency(consumed)} · Overage={fmt_currency(cust_overage)} ·
        30d Burn={fmt_currency(burn)}/day
    </div>""", unsafe_allow_html=True)
    st.markdown(f"""<div style="font-size:0.68rem; color:{SF_NAVY}; margin:2px 0 10px 0; padding:6px 10px;
        background:#FFF8E1; border-radius:4px; border-left:3px solid {SF_ORANGE};">
        <strong>Customer View ({mp:.1f}% markup):</strong>&nbsp;
        Entitlement={fmt_currency(cust_entitlement * markup_mult)} · Capacity={fmt_currency(cap * markup_mult)} ·
        Free={fmt_currency(free_u * markup_mult)} · Rollover={fmt_currency(roll * markup_mult)} ·
        Consumed={fmt_currency(consumed * markup_mult)} · Overage={fmt_currency(cust_overage * markup_mult)} ·
        30d Burn={fmt_currency(burn * markup_mult)}/day
    </div>""", unsafe_allow_html=True)

    daily_cust = cust_daily

    fig_dd = go.Figure()
    fig_dd.add_trace(go.Bar(x=daily_cust["USAGE_DATE"], y=daily_cust["USAGE_IN_CURRENCY"],
        name="Daily Usage", marker_color=SF_LIGHT_BLUE, opacity=0.7))
    fig_dd.add_trace(go.Scatter(x=daily_cust["USAGE_DATE"], y=daily_cust["CUMULATIVE"],
        name="Cumulative", line=dict(color=SF_BLUE, width=2.5),
        fill="tozeroy", fillcolor="rgba(41,181,232,0.1)"))
    fig_dd.add_trace(go.Scatter(
        x=[daily_cust["USAGE_DATE"].min(), daily_cust["USAGE_DATE"].max()],
        y=[cap + free_u, cap + free_u],
        name="Entitlement Limit", line=dict(color=SF_ORANGE, width=2, dash="dash")))
    fig_dd.update_layout(**{**PLOTLY_LAYOUT, "height": 350, "yaxis_tickformat": "$,.0f"})
    st.plotly_chart(fig_dd, use_container_width=True, config=PLOTLY_CONFIG)

    section_header("Usage by Service Type")
    svc_daily = cust_usage.groupby(["USAGE_DATE", "SERVICE_TYPE"])["USAGE_IN_CURRENCY"].sum().reset_index()
    fig_svc = go.Figure()
    for stype in svc_daily["SERVICE_TYPE"].unique():
        sdata = svc_daily[svc_daily["SERVICE_TYPE"] == stype]
        fig_svc.add_trace(go.Scatter(x=sdata["USAGE_DATE"], y=sdata["USAGE_IN_CURRENCY"],
            name=stype, mode="lines", line=dict(width=1.5, color=COLOR_MAP.get(stype, SF_GRAY))))
    fig_svc.update_layout(**{**PLOTLY_LAYOUT, "height": 300, "yaxis_tickformat": "$,.0f"})
    st.plotly_chart(fig_svc, use_container_width=True, config=PLOTLY_CONFIG)

with tab_comparison:
    section_header("Customer Comparison")

    comp_metric = st.radio("Compare by", ["Total Consumption ($)", "Total Credits", "30d Burn Rate ($/day)"],
        horizontal=True, key="comp_metric")

    cust_comp = []
    for cust_name in customers:
        cu = usage[usage["SOLD_TO_CUSTOMER_NAME"] == cust_name]
        l30 = cu[cu["USAGE_DATE"] >= (pd.Timestamp.now() - timedelta(days=30))]
        cust_comp.append({
            "Customer": cust_name,
            "Total Consumption ($)": float(cu["USAGE_IN_CURRENCY"].sum()),
            "Total Credits": float(cu["USAGE"].sum()),
            "30d Burn Rate ($/day)": round(float(l30["USAGE_IN_CURRENCY"].mean()), 2) if len(l30) > 0 else 0
        })
    df_comp = pd.DataFrame(cust_comp).sort_values(comp_metric, ascending=True)

    fig_comp = go.Figure()
    fig_comp.add_trace(go.Bar(
        y=df_comp["Customer"], x=df_comp[comp_metric],
        orientation="h", marker_color=SF_BLUE,
        text=[fmt_currency(v) if "$" in comp_metric else f"{v:,.0f}" for v in df_comp[comp_metric]],
        textposition="outside", textfont=dict(size=10)))
    fig_comp.update_layout(**{**PLOTLY_LAYOUT, "height": max(300, len(customers) * 35),
        "margin": dict(l=200, r=80, t=20, b=20), "showlegend": False,
        "xaxis_tickformat": "$,.0f" if "$" in comp_metric else ",.0f"})
    st.plotly_chart(fig_comp, use_container_width=True, config=PLOTLY_CONFIG)

    section_header("Monthly Trend Comparison")
    top_5 = df_comp.sort_values(comp_metric, ascending=False).head(5)["Customer"].tolist()
    monthly_top = usage_monthly[usage_monthly["SOLD_TO_CUSTOMER_NAME"].isin(top_5)]
    monthly_top_agg = monthly_top.groupby(["MONTH", "SOLD_TO_CUSTOMER_NAME"])["USAGE_IN_CURRENCY"].sum().reset_index()

    fig_trend = go.Figure()
    for cust in top_5:
        cd = monthly_top_agg[monthly_top_agg["SOLD_TO_CUSTOMER_NAME"] == cust]
        fig_trend.add_trace(go.Scatter(x=cd["MONTH"], y=cd["USAGE_IN_CURRENCY"],
            name=cust, mode="lines+markers", line=dict(width=2)))
    fig_trend.update_layout(**{**PLOTLY_LAYOUT, "height": 350, "yaxis_tickformat": "$,.0f", "xaxis_tickformat": "%b %Y"})
    st.plotly_chart(fig_trend, use_container_width=True, config=PLOTLY_CONFIG)

with tab_margins:
    section_header("Markup Configuration & Revenue")

    margin_data = []
    for _, m in markup.iterrows():
        cust_name = m["SOLD_TO_CUSTOMER_NAME"]
        cu = usage[usage["SOLD_TO_ORGANIZATION_NAME"] == m["SOLD_TO_ORGANIZATION_NAME"]]
        raw_spend = float(cu["USAGE_IN_CURRENCY"].sum())
        mp = float(m["MARKUP_PCT"])
        margin_rev = raw_spend * mp
        customer_sees = raw_spend + margin_rev
        margin_data.append({
            "Customer": cust_name,
            "Markup (%)": f"{mp * 100:.1f}%",
            "Raw Spend ($)": raw_spend,
            "Margin Revenue ($)": margin_rev,
            "Customer Sees ($)": customer_sees,
            "Account Locator": m["CONSUMER_ACCOUNT_LOCATOR"],
            "Active": m["IS_ACTIVE"]
        })

    df_margin = pd.DataFrame(margin_data).sort_values("Margin Revenue ($)", ascending=False)

    m1, m2 = st.columns(2)
    with m1:
        st.markdown(kpi_card("Total Margin Revenue", fmt_currency(float(df_margin["Margin Revenue ($)"].sum())),
            f"From {len(df_margin)} customers",
            f"Total raw spend: {fmt_currency(float(df_margin['Raw Spend ($)'].sum()))}",
            SF_GREEN, SF_ORANGE), unsafe_allow_html=True)
    with m2:
        avg_mp = float(markup["MARKUP_PCT"].mean()) * 100
        st.markdown(kpi_card("Avg Markup", f"{avg_mp:.1f}%",
            f"Range: {float(markup['MARKUP_PCT'].min()) * 100:.1f}% — {float(markup['MARKUP_PCT'].max()) * 100:.1f}%",
            f"Customers with 0% markup: {int((markup['MARKUP_PCT'] == 0).sum())}",
            SF_GRAY, SF_DARK_BLUE), unsafe_allow_html=True)

    st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)

    st.dataframe(df_margin, hide_index=True, use_container_width=True)
    st.download_button("Download margin report as CSV", df_margin.to_csv(index=False),
        "reseller_margin_report.csv", "text/csv", key="dl_margins")

    section_header("Margin Revenue by Customer")
    df_margin_sorted = df_margin.sort_values("Margin Revenue ($)", ascending=True)
    fig_margin = go.Figure()
    fig_margin.add_trace(go.Bar(
        y=df_margin_sorted["Customer"], x=df_margin_sorted["Margin Revenue ($)"],
        orientation="h", marker_color=SF_ORANGE,
        text=[fmt_currency(v) for v in df_margin_sorted["Margin Revenue ($)"]],
        textposition="outside", textfont=dict(size=10)))
    fig_margin.update_layout(**{**PLOTLY_LAYOUT, "height": max(300, len(df_margin) * 30),
        "margin": dict(l=200, r=80, t=20, b=20), "showlegend": False, "xaxis_tickformat": "$,.0f"})
    st.plotly_chart(fig_margin, use_container_width=True, config=PLOTLY_CONFIG)
