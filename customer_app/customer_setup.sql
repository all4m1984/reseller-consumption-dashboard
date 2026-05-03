--------------------------------------------------------------------
-- Customer Setup Script
-- Run this on YOUR Snowflake account as ACCOUNTADMIN
--
-- This script:
--   1. Creates a database from the reseller's billing share
--   2. Grants access to your roles
--   3. Verifies the data is accessible
--
-- Prerequisites:
--   - You received a share notification from your reseller
--   - You have ACCOUNTADMIN role access
--   - Replace <YOUR_ROLE> with the role you want to grant access to
--------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

--------------------------------------------------------------------
-- STEP 1: Create database from the reseller's share
--   Replace <RESELLER_ORG>, <RESELLER_ACCOUNT> with values provided by your reseller
--   Example: FROM SHARE MYORG.MYACCOUNT.RESELLER_BILLING_SHARE
--
--   To find these values, ask your reseller to run:
--     SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT();
--------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RESELLER_BILLING
    FROM SHARE <RESELLER_ORG>.<RESELLER_ACCOUNT>.RESELLER_BILLING_SHARE;

--------------------------------------------------------------------
-- STEP 2: Grant access to your role
--   Replace SYSADMIN with your preferred role
--------------------------------------------------------------------
GRANT IMPORTED PRIVILEGES ON DATABASE RESELLER_BILLING TO ROLE SYSADMIN;

--------------------------------------------------------------------
-- STEP 3: Verify data access
--   You should see your contract details (capacity and free usage)
--------------------------------------------------------------------
SELECT * FROM RESELLER_BILLING.SHARED.PARTNER_CONTRACT_ITEMS;

--------------------------------------------------------------------
-- STEP 4: Quick data check
--   Verify all 4 views return data
--------------------------------------------------------------------
SELECT 'Contract Items' AS view_name, COUNT(*) AS rows FROM RESELLER_BILLING.SHARED.PARTNER_CONTRACT_ITEMS
UNION ALL
SELECT 'Usage Daily', COUNT(*) FROM RESELLER_BILLING.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY
UNION ALL
SELECT 'Remaining Balance', COUNT(*) FROM RESELLER_BILLING.SHARED.PARTNER_REMAINING_BALANCE_DAILY
UNION ALL
SELECT 'Rate Sheet', COUNT(*) FROM RESELLER_BILLING.SHARED.PARTNER_RATE_SHEET_DAILY;

--------------------------------------------------------------------
-- STEP 5 (Optional): Set up the billing dashboard
--   1. Go to Snowsight > Streamlit > + Streamlit App
--   2. Paste the content of customer_app/streamlit_app.py
--      (provided by your reseller)
--   3. In the packages panel, add: plotly
--   4. Run the app
--
-- The dashboard provides:
--   - Contract overview with capacity depletion forecast
--   - Usage breakout by service type
--   - Contract and subscription details
--   - Consumption analytics
--
-- Data refreshes automatically (up to 24-hour latency).
-- No action required on your part to keep data current.
--------------------------------------------------------------------
