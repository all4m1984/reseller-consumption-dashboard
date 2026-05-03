import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session
from datetime import datetime, timedelta

st.set_page_config(page_title="Snowflake Capacity Consumption Dashboard", layout="wide", page_icon="https://upload.wikimedia.org/wikipedia/commons/f/ff/Snowflake_Logo.svg")

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

# --- NOTE: This app runs on the CUSTOMER account ---
# It reads from RESELLER_BILLING.SHARED.* (created from the share)
# Data is already marked up and row-filtered by the secure views
# Customer sees ONLY their own data at the reseller's marked-up rates

st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    * { font-family: 'Inter', sans-serif !important; }
    .main .block-container { padding-top: 1.5rem; max-width: 1200px; }
    .stTabs [data-baseweb="tab-list"] { gap: 0px; border-bottom: 2px solid #E8F4FA; }
    .stTabs [data-baseweb="tab"] { padding: 8px 24px; font-weight: 500; color: #6E7681; border: none; background: transparent; }
    .stTabs [aria-selected="true"] { color: #11567F; border-bottom: 3px solid #29B5E8; font-weight: 600; background: transparent; }
    .stDownloadButton > button { background: transparent; color: #29B5E8; border: 1px solid #29B5E8; font-size: 0.8rem; padding: 4px 12px; }
    .stDownloadButton > button:hover { background: #E8F4FA; }
    div[data-testid="stDataFrame"] th { background-color: #29B5E8 !important; color: white !important; font-weight: 600 !important; font-size: 0.8rem !important; }
    div[data-testid="stDataFrame"] td { font-size: 0.8rem !important; }
</style>
""", unsafe_allow_html=True)

st.markdown(f"""
<div style="display:flex; align-items:center; gap:14px; padding:12px 0 16px 0; border-bottom:2px solid {SF_LIGHT_BLUE}; margin-bottom:16px;">
    <img src="{SNOWFLAKE_LOGO}" alt="Snowflake" style="height:40px; width:auto;">
    <div>
        <div style="font-size:1.4rem; font-weight:700; color:{SF_NAVY}; letter-spacing:-0.3px;">Snowflake Capacity Consumption Dashboard</div>
        <div style="font-size:0.78rem; color:{SF_GRAY}; margin-top:2px;">Billing visibility for your Snowflake account</div>
    </div>
</div>
""", unsafe_allow_html=True)

PLOTLY_CONFIG = {"displayModeBar": True, "staticPlot": False, "scrollZoom": False}
PLOTLY_LAYOUT = dict(
    plot_bgcolor="white", paper_bgcolor="white",
    font=dict(family="Inter", size=11, color=SF_NAVY),
    margin=dict(l=50, r=20, t=30, b=40),
    legend=dict(orientation="h", yanchor="bottom", y=-0.25, xanchor="center", x=0.5, font=dict(size=9)),
    yaxis=dict(gridcolor="#F0F2F5", zeroline=False),
    xaxis=dict(gridcolor="#F0F2F5", zeroline=False))


def kpi_card(title, value, subtitle="", delta_text="", delta_color=SF_GRAY, border_top_color=SF_BLUE):
    return f"""
    <div style="background:white; border-radius:8px; padding:14px 16px; border-top:3px solid {border_top_color};
        box-shadow:0 1px 4px rgba(0,0,0,0.06); min-height:130px;">
        <div style="font-size:0.68rem; font-weight:600; color:{SF_GRAY}; text-transform:uppercase; letter-spacing:0.5px;
            margin-bottom:6px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">{title}</div>
        <div style="font-size:1.5rem; font-weight:700; color:{SF_NAVY}; margin-bottom:6px; line-height:1.2;">{value}</div>
        <div style="font-size:0.65rem; color:{delta_color}; line-height:1.3; margin-bottom:3px;">{delta_text}</div>
        <div style="font-size:0.62rem; color:{SF_GRAY}; line-height:1.3;">{subtitle}</div>
    </div>"""


def section_header(text):
    st.markdown(f'<h3 style="color:{SF_NAVY}; font-weight:600; font-size:1.1rem; margin:20px 0 12px 0; border-bottom:2px solid {SF_LIGHT_BLUE}; padding-bottom:8px;">{text}</h3>', unsafe_allow_html=True)


def fmt_currency(val, prefix="$"):
    if val is None: return f"{prefix}0"
    if abs(val) >= 1_000_000: return f"{prefix}{val/1_000_000:,.1f}M"
    if abs(val) >= 1_000: return f"{prefix}{val:,.0f}"
    return f"{prefix}{val:,.2f}"


def fmt_pct(val):
    return "0.0%" if val is None else f"{val:.1f}%"


@st.cache_data(ttl=3600)
def load_data():
    session = get_active_session()
    db = "RESELLER_BILLING"
    contracts = session.sql(f"SELECT * FROM {db}.SHARED.PARTNER_CONTRACT_ITEMS").to_pandas()
    usage = session.sql(f"SELECT * FROM {db}.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY").to_pandas()
    balance = session.sql(f"SELECT * FROM {db}.SHARED.PARTNER_REMAINING_BALANCE_DAILY").to_pandas()
    rates = session.sql(f"SELECT * FROM {db}.SHARED.PARTNER_RATE_SHEET_DAILY").to_pandas()
    for df in [usage, balance, rates]:
        for c in [col for col in df.columns if "DATE" in col.upper() or col.upper() == "DATE"]:
            df[c] = pd.to_datetime(df[c])
    for c in contracts.columns:
        if "DATE" in c.upper(): contracts[c] = pd.to_datetime(contracts[c])
    return contracts, usage, balance, rates


contracts, usage, balance, rates = load_data()

customer_name = contracts["SOLD_TO_CUSTOMER_NAME"].iloc[0] if len(contracts) > 0 else "Customer"
contract_number = contracts["SOLD_TO_CONTRACT_NUMBER"].iloc[0] if len(contracts) > 0 else ""

st.markdown(f"""
<div style="background:linear-gradient(135deg, {SF_DARK_BLUE}, {SF_NAVY}); padding:20px 28px; border-radius:8px; margin-bottom:20px;">
    <div style="font-size:1.3rem; font-weight:700; color:white;">Active Contract — {customer_name}</div>
    <div style="font-size:0.82rem; color:{SF_BLUE}; margin-top:4px;">Contract ID: {contract_number}</div>
</div>
""", unsafe_allow_html=True)

capacity_row = contracts[contracts["CONTRACT_ITEM"] == "capacity"]
free_row = contracts[contracts["CONTRACT_ITEM"] == "free usage"]
total_capacity = float(capacity_row["AMOUNT"].iloc[0]) if len(capacity_row) > 0 else 0
free_usage_amt = float(free_row["AMOUNT"].iloc[0]) if len(free_row) > 0 else 0
total_entitlement = total_capacity + free_usage_amt
contract_start = contracts["START_DATE"].iloc[0] if len(contracts) > 0 else None
contract_end = contracts["END_DATE"].iloc[0] if len(contracts) > 0 else None

latest_bal = balance.sort_values("DATE", ascending=False).head(1)
remaining_capacity = float(latest_bal["CAPACITY_BALANCE"].iloc[0]) if len(latest_bal) > 0 else 0
remaining_free = float(latest_bal["FREE_USAGE_BALANCE"].iloc[0]) if len(latest_bal) > 0 else 0
on_demand = float(latest_bal["ON_DEMAND_CONSUMPTION_BALANCE"].iloc[0]) if len(latest_bal) > 0 else 0
rollover = float(latest_bal["ROLLOVER_BALANCE"].iloc[0]) if len(latest_bal) > 0 else 0

total_consumption = float(usage["USAGE_IN_CURRENCY"].sum())
consumption_pct = (total_consumption / total_entitlement * 100) if total_entitlement > 0 else 0
overage = abs(on_demand) if on_demand < 0 else 0
if overage == 0 and total_consumption > total_entitlement and remaining_capacity <= 0:
    overage = total_consumption - total_entitlement

contract_expired = contract_end is not None and pd.Timestamp.now() > contract_end
raw_days_remaining = (contract_end - pd.Timestamp.now()).days if contract_end is not None else 0
days_remaining = max(raw_days_remaining, 0)

daily_usage_all = usage.groupby("USAGE_DATE")["USAGE_IN_CURRENCY"].sum().reset_index().sort_values("USAGE_DATE")
daily_usage_all["CUMULATIVE"] = daily_usage_all["USAGE_IN_CURRENCY"].cumsum()
last_30d = daily_usage_all[daily_usage_all["USAGE_DATE"] >= (pd.Timestamp.now() - timedelta(days=30))]
avg_daily_burn = float(last_30d["USAGE_IN_CURRENCY"].mean()) if len(last_30d) > 0 else float(daily_usage_all["USAGE_IN_CURRENCY"].mean())
total_remaining_funds = remaining_capacity + rollover + remaining_free

capacity_depleted = remaining_capacity <= 0 or overage > 0

if capacity_depleted:
    days_until_depleted = 0
    crossed = daily_usage_all[daily_usage_all["CUMULATIVE"] >= total_entitlement]
    depletion_date = crossed["USAGE_DATE"].iloc[0].strftime("%Y-%m-%d") if len(crossed) > 0 else "Depleted"
elif avg_daily_burn > 0 and total_remaining_funds > 0:
    days_until_depleted = int(total_remaining_funds / avg_daily_burn)
    depletion_date = (pd.Timestamp.now() + timedelta(days=days_until_depleted)).strftime("%Y-%m-%d")
else:
    days_until_depleted = 999
    depletion_date = "N/A"

depletion_before_expiry = not contract_expired and not capacity_depleted and days_until_depleted < days_remaining
depletion_urgency_color = SF_RED if capacity_depleted or days_until_depleted < 60 else SF_ORANGE if days_until_depleted < 120 else SF_GREEN

k1, k2, k3, k4, k5, k6 = st.columns(6)
with k1:
    st.markdown(kpi_card("Total Consumption", fmt_currency(total_consumption),
        f"Contract start: {contract_start.strftime('%Y-%m-%d') if contract_start else 'N/A'}",
        f"▲ {fmt_pct(consumption_pct)} of entitlement ({fmt_currency(total_entitlement)})",
        SF_BLUE, SF_BLUE), unsafe_allow_html=True)
with k2:
    st.markdown(kpi_card("Total Credits Used",
        fmt_currency(float(usage["USAGE"].sum()), prefix=""),
        f"Across {usage['USAGE_DATE'].nunique()} active days",
        f"Avg {float(usage['USAGE'].sum()) / max(usage['USAGE_DATE'].nunique(), 1):,.1f} credits/day",
        SF_GRAY, SF_DARK_BLUE), unsafe_allow_html=True)
with k3:
    st.markdown(kpi_card("Overage", fmt_currency(overage),
        "On-demand spend" if overage > 0 else "No overage incurred",
        f"Rollover remaining: {fmt_currency(rollover)}",
        SF_RED if overage > 0 else SF_GREEN, SF_RED if overage > 0 else SF_GREEN), unsafe_allow_html=True)
with k4:
    bal_color = SF_RED if remaining_capacity <= 0 else SF_ORANGE if consumption_pct > 80 else SF_GREEN
    st.markdown(kpi_card("Remaining Balance", fmt_currency(remaining_capacity),
        f"Last updated: {latest_bal['DATE'].iloc[0].strftime('%Y-%m-%d') if len(latest_bal) > 0 else 'N/A'}",
        f"Free: {fmt_currency(remaining_free)} · Rollover: {fmt_currency(rollover)}",
        SF_GRAY, bal_color), unsafe_allow_html=True)
with k5:
    if contract_expired:
        expiry_label, expiry_delta, expiry_border = "EXPIRED", f"Contract ended {abs(raw_days_remaining)} days ago", SF_RED
    elif days_remaining == 0:
        expiry_label, expiry_delta, expiry_border = "TODAY", "⚠ Contract expires today — initiate renewal", SF_RED
    elif days_remaining < 30:
        expiry_label, expiry_delta, expiry_border = f"{days_remaining} days", "⚠ Expiring soon — initiate renewal", SF_RED
    elif days_remaining < 60:
        expiry_label, expiry_delta, expiry_border = f"{days_remaining} days", "⚠ Approaching expiry", SF_ORANGE
    else:
        expiry_label, expiry_delta, expiry_border = f"{days_remaining} days", "", SF_BLUE
    st.markdown(kpi_card("Days Until Expiry", expiry_label,
        f"Expiry: {contract_end.strftime('%Y-%m-%d') if contract_end else 'N/A'}", expiry_delta,
        SF_RED if contract_expired or days_remaining < 30 else SF_ORANGE if days_remaining < 60 else SF_GRAY,
        expiry_border), unsafe_allow_html=True)
with k6:
    if capacity_depleted:
        depl_label, depl_warning, depl_border = "DEPLETED", f"⚠ Exhausted on {depletion_date}", SF_RED
        depl_sub = f"Remaining funds: {fmt_currency(total_remaining_funds)}"
    elif contract_expired:
        depl_label, depl_warning, depl_border = f"{days_until_depleted} days", "Contract expired — balance will not renew", SF_ORANGE
        depl_sub = f"Remaining funds: {fmt_currency(total_remaining_funds)}"
    elif depletion_before_expiry:
        depl_label, depl_warning, depl_border = f"{days_until_depleted} days", f"⚠ Runs out ~{depletion_date} (before contract ends)", SF_RED
        depl_sub = f"Remaining: {fmt_currency(total_remaining_funds)} at {fmt_currency(avg_daily_burn)}/day"
    else:
        depl_label = f"{days_until_depleted} days" if days_until_depleted < 999 else "N/A"
        depl_warning, depl_border = "✓ Sufficient until contract end", SF_GREEN
        depl_sub = f"Remaining: {fmt_currency(total_remaining_funds)} at {fmt_currency(avg_daily_burn)}/day"
    st.markdown(kpi_card("Days to Depletion", depl_label, depl_sub, depl_warning,
        depletion_urgency_color, depl_border), unsafe_allow_html=True)

if capacity_depleted:
    msg = f"Current overage: <strong>{fmt_currency(overage)}</strong>." if overage > 0 else f"Rollover of <strong>{fmt_currency(rollover)}</strong> absorbing excess."
    st.markdown(f"""<div style="background:#FFEBEE; border-left:4px solid {SF_RED}; padding:12px 16px; border-radius:4px; margin:8px 0; font-size:0.82rem;">
        <strong style="color:{SF_RED};">⚠ Capacity Depleted:</strong>
        <span style="color:{SF_NAVY};"> Capacity of <strong>{fmt_currency(total_capacity)}</strong> exhausted on <strong>{depletion_date}</strong>. {msg} Contact your account team.</span>
    </div>""", unsafe_allow_html=True)
elif depletion_before_expiry:
    st.markdown(f"""<div style="background:#FFF3E0; border-left:4px solid {SF_ORANGE}; padding:12px 16px; border-radius:4px; margin:8px 0; font-size:0.82rem;">
        <strong style="color:{SF_ORANGE};">⚠ Top-Up Advisory:</strong>
        <span style="color:{SF_NAVY};"> At <strong>{fmt_currency(avg_daily_burn)}/day</strong>, balance of <strong>{fmt_currency(total_remaining_funds)}</strong> exhausted by <strong>{depletion_date}</strong> — <strong>{days_remaining - days_until_depleted} days before</strong> contract expires.</span>
    </div>""", unsafe_allow_html=True)
if contract_expired:
    st.markdown(f"""<div style="background:#FFEBEE; border-left:4px solid {SF_RED}; padding:12px 16px; border-radius:4px; margin:8px 0; font-size:0.82rem;">
        <strong style="color:{SF_RED};">⚠ Contract Expired:</strong>
        <span style="color:{SF_NAVY};"> Contract ended <strong>{contract_end.strftime('%Y-%m-%d') if contract_end else 'N/A'}</strong> ({abs(raw_days_remaining)} days ago). Contact your account team to renew.</span>
    </div>""", unsafe_allow_html=True)

st.markdown(f"""<div style="font-size:0.7rem; color:{SF_GRAY}; margin:8px 0 4px 0; padding:4px 8px; background:{SF_LIGHT_GRAY}; border-radius:4px;">
    Entitlement={fmt_currency(total_entitlement)} · Capacity={fmt_currency(total_capacity)} · Free={fmt_currency(free_usage_amt)} · Rollover={fmt_currency(rollover)} · Consumed={fmt_currency(total_consumption)} · Overage={fmt_currency(overage)} · 30d Burn={fmt_currency(avg_daily_burn)}/day
</div>""", unsafe_allow_html=True)

tab_overview, tab_breakout, tab_contracts, tab_consumption = st.tabs(["Overview", "Contract Breakout", "Active Contracts", "Consumption"])

with tab_overview:
    section_header("Cumulative Usage vs Capacity")
    col_filter, _ = st.columns([3, 7])
    with col_filter:
        period = st.selectbox("Select Period", ["30 days", "60 days", "90 days", "180 days", "All"], index=4, key="ov_period")
    cutoff = usage["USAGE_DATE"].min() if period == "All" else pd.Timestamp.now() - timedelta(days={"30 days":30,"60 days":60,"90 days":90,"180 days":180}[period])
    duf = daily_usage_all[daily_usage_all["USAGE_DATE"] >= cutoff].copy()
    last_date = daily_usage_all["USAGE_DATE"].max()
    last_cum = float(daily_usage_all["CUMULATIVE"].iloc[-1])
    future_dates = pd.date_range(start=last_date + timedelta(days=1), periods=60)
    proj = [last_cum + avg_daily_burn * (i + 1) for i in range(60)]

    fig = go.Figure()
    fig.add_trace(go.Bar(x=duf["USAGE_DATE"], y=duf["USAGE_IN_CURRENCY"], name="Daily Usage", marker_color=SF_LIGHT_BLUE, opacity=0.7))
    fig.add_trace(go.Scatter(x=duf["USAGE_DATE"], y=duf["CUMULATIVE"], name="Cumulative Usage", line=dict(color=SF_BLUE, width=2.5), fill="tozeroy", fillcolor="rgba(41,181,232,0.1)"))
    fig.add_trace(go.Scatter(x=[duf["USAGE_DATE"].min(), future_dates[-1]], y=[total_entitlement, total_entitlement], name="Entitlement Limit", line=dict(color=SF_ORANGE, width=2, dash="dash")))
    fig.add_trace(go.Scatter(x=future_dates, y=proj, name="Projection (30d avg)", line=dict(color=SF_GRAY, width=1.5, dash="dot")))
    fig.update_layout(**{**PLOTLY_LAYOUT, "height": 380, "yaxis_tickformat": "$,.0f"})
    cc, kc = st.columns([8, 2])
    with cc:
        st.plotly_chart(fig, use_container_width=True, config=PLOTLY_CONFIG)
    with kc:
        st.markdown("<div style='height:60px'></div>", unsafe_allow_html=True)
        st.markdown(f"""<div style="background:white; border-radius:6px; padding:16px 18px; border-left:3px solid {SF_BLUE}; box-shadow:0 1px 3px rgba(0,0,0,0.05);">
            <div style="font-size:0.72rem; color:{SF_GRAY}; text-transform:uppercase;">Avg Daily (30d)</div>
            <div style="font-size:1.4rem; font-weight:700; color:{SF_NAVY}; margin-top:8px;">{fmt_currency(avg_daily_burn)}</div>
        </div>""", unsafe_allow_html=True)

with tab_breakout:
    section_header("Contract Breakout")
    st.markdown(f'<div style="font-size:0.75rem; color:{SF_GRAY}; margin-bottom:12px;">Click legend to select/deselect</div>', unsafe_allow_html=True)
    bc1, _ = st.columns([4, 6])
    with bc1:
        sp = st.radio("", ["1M", "3M", "1Y", "QTD", "YTD", "All"], horizontal=True, index=5, key="bp")
    now = pd.Timestamp.now()
    if sp == "QTD": cb = pd.Timestamp(now.year, ((now.month-1)//3)*3+1, 1)
    elif sp == "YTD": cb = pd.Timestamp(now.year, 1, 1)
    elif sp == "All": cb = usage["USAGE_DATE"].min()
    else: cb = now - timedelta(days={"1M":30,"3M":90,"1Y":365}[sp])
    uf = usage[usage["USAGE_DATE"] >= cb]
    dbs = uf.groupby(["USAGE_DATE", "SERVICE_TYPE"])["USAGE_IN_CURRENCY"].sum().reset_index()
    fig2 = go.Figure()
    for st2 in dbs["SERVICE_TYPE"].unique():
        sd = dbs[dbs["SERVICE_TYPE"] == st2]
        fig2.add_trace(go.Scatter(x=sd["USAGE_DATE"], y=sd["USAGE_IN_CURRENCY"], name=st2, mode="lines", line=dict(width=1.5, color=COLOR_MAP.get(st2, SF_GRAY))))
    fig2.update_layout(**{**PLOTLY_LAYOUT, "height": 400, "yaxis_tickformat": "$,.0f", "yaxis_title": "Consumption ($)", "xaxis_title": "Date"})
    st.plotly_chart(fig2, use_container_width=True, config=PLOTLY_CONFIG)

with tab_contracts:
    section_header("Active Contract")
    cd = contracts.copy()
    cd["TOTAL_CONSUMPTION"] = total_consumption
    cd["CAPACITY_REMAINING"] = remaining_capacity
    cols_c = ["CONTRACT_ITEM","AMOUNT","CURRENCY","START_DATE","END_DATE","EXPIRATION_DATE","TOTAL_CONSUMPTION","CAPACITY_REMAINING"]
    cs = cd[[c for c in cols_c if c in cd.columns]].copy()
    cs = cs.rename(columns={"CONTRACT_ITEM":"Agreement Type","AMOUNT":"Capacity/Purchase($)","CURRENCY":"Currency","START_DATE":"Start Date","END_DATE":"End Date","EXPIRATION_DATE":"Expiration","TOTAL_CONSUMPTION":"Consumption($)","CAPACITY_REMAINING":"Remaining($)"})
    for col in cs.columns:
        if "Date" in col or "Expiration" in col:
            cs[col] = cs[col].dt.strftime("%Y-%m-%d")
    st.dataframe(cs, hide_index=True, use_container_width=True)
    st.download_button("Download as CSV", cs.to_csv(index=False), "contract.csv", "text/csv", key="dl_c")

    section_header("Active Subscription")
    rl = rates.sort_values("DATE", ascending=False).drop_duplicates(subset=["ACCOUNT_NAME", "SERVICE_TYPE"])
    sc = ["ACCOUNT_NAME","REGION","SERVICE_LEVEL","CURRENCY","SERVICE_TYPE","EFFECTIVE_RATE"]
    ss = rl[[c for c in sc if c in rl.columns]].rename(columns={"ACCOUNT_NAME":"Account","REGION":"Region","SERVICE_LEVEL":"Edition","CURRENCY":"Currency","SERVICE_TYPE":"Service","EFFECTIVE_RATE":"Rate ($)"})
    st.dataframe(ss, hide_index=True, use_container_width=True)
    st.download_button("Download as CSV", ss.to_csv(index=False), "subscription.csv", "text/csv", key="dl_s")

with tab_consumption:
    ct1, ct2 = st.tabs(["Consumption", "Cost Use"])
    with ct1:
        comp = float(usage[usage["USAGE_TYPE"]=="compute"]["USAGE_IN_CURRENCY"].sum())
        csvc = float(usage[usage["USAGE_TYPE"]=="cloud services"]["USAGE_IN_CURRENCY"].sum())
        stor = float(usage[usage["USAGE_TYPE"]=="storage"]["USAGE_IN_CURRENCY"].sum())
        othr = total_consumption - comp - csvc - stor
        ck1, ck2, ck3, ck4 = st.columns(4)
        with ck1:
            st.markdown(kpi_card("Compute", fmt_currency(comp), f"{fmt_pct(comp/total_consumption*100 if total_consumption else 0)} of total",
                f"Credits: {usage[usage['USAGE_TYPE']=='compute']['USAGE'].sum():,.0f}", SF_GRAY, SF_BLUE), unsafe_allow_html=True)
        with ck2:
            st.markdown(kpi_card("Cloud Services", fmt_currency(csvc), f"{fmt_pct(csvc/total_consumption*100 if total_consumption else 0)} of total",
                f"Credits: {usage[usage['USAGE_TYPE']=='cloud services']['USAGE'].sum():,.0f}", SF_GRAY, "#5B9BD5"), unsafe_allow_html=True)
        with ck3:
            st.markdown(kpi_card("Storage", fmt_currency(stor), f"{fmt_pct(stor/total_consumption*100 if total_consumption else 0)} of total",
                f"Credits: {usage[usage['USAGE_TYPE']=='storage']['USAGE'].sum():,.0f}", SF_GRAY, SF_ORANGE), unsafe_allow_html=True)
        with ck4:
            st.markdown(kpi_card("Other", fmt_currency(othr), f"{fmt_pct(othr/total_consumption*100 if total_consumption else 0)} of total",
                "Serverless+Clustering+Pipe+Transfer", SF_GRAY, SF_GREEN), unsafe_allow_html=True)

        section_header("Monthly Consumption Trend")
        um = usage.copy()
        um["MONTH"] = um["USAGE_DATE"].dt.to_period("M").dt.to_timestamp()
        ma = um.groupby(["MONTH", "USAGE_TYPE"])["USAGE_IN_CURRENCY"].sum().reset_index()
        fig3 = px.bar(ma, x="MONTH", y="USAGE_IN_CURRENCY", color="USAGE_TYPE", barmode="group",
            color_discrete_map=USAGE_COLOR_MAP, labels={"USAGE_IN_CURRENCY":"USD ($)","MONTH":"","USAGE_TYPE":""})
        fig3.update_layout(**{**PLOTLY_LAYOUT, "height": 350, "yaxis_tickformat": "$,.0f", "xaxis_tickformat": "%b %Y"})
        st.plotly_chart(fig3, use_container_width=True, config=PLOTLY_CONFIG)

    with ct2:
        section_header("Consumption Breakout")
        ts = usage.groupby("USAGE_TYPE").agg(TOTAL=("USAGE_IN_CURRENCY","sum")).reset_index().sort_values("TOTAL", ascending=True)
        fig4 = go.Figure()
        fig4.add_trace(go.Bar(y=ts["USAGE_TYPE"], x=ts["TOTAL"], orientation="h", marker_color=SF_BLUE,
            text=[fmt_currency(v) for v in ts["TOTAL"]], textposition="outside", textfont=dict(size=10)))
        fig4.update_layout(**{**PLOTLY_LAYOUT, "height": 280, "margin": dict(l=160, r=80, t=20, b=20), "xaxis_tickformat": "$,.0f", "showlegend": False})
        st.plotly_chart(fig4, use_container_width=True, config=PLOTLY_CONFIG)

        section_header("Daily Cost by Service Type")
        dc = usage.groupby(["USAGE_DATE", "SERVICE_TYPE"])["USAGE_IN_CURRENCY"].sum().reset_index()
        fig5 = px.bar(dc, x="USAGE_DATE", y="USAGE_IN_CURRENCY", color="SERVICE_TYPE", barmode="stack",
            color_discrete_map=COLOR_MAP, labels={"USAGE_IN_CURRENCY":"USD ($)","USAGE_DATE":"","SERVICE_TYPE":""})
        fig5.update_layout(**{**PLOTLY_LAYOUT, "height": 350, "yaxis_tickformat": "$,.0f"})
        st.plotly_chart(fig5, use_container_width=True, config=PLOTLY_CONFIG)
