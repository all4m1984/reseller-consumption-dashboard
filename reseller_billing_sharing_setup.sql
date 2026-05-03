--------------------------------------------------------------------
-- Reseller Billing Data Sharing with Markup
-- Shares billing data to customer accounts via secure views
-- - Row-level isolation: each customer sees only their own data
-- - Markup applied: reseller controls per-customer markup (max 5%)
-- - Real-time: consumers always see latest data, zero copy
--------------------------------------------------------------------

--------------------------------------------------------------------
-- STEP 1: Create schemas
--------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS RESELLER_BILLING_FINAL.SHARING_CONFIG;
CREATE SCHEMA IF NOT EXISTS RESELLER_BILLING_FINAL.SHARED;

--------------------------------------------------------------------
-- STEP 2: Account mapping table
--   Maps customer org → consumer Snowflake account locator
--------------------------------------------------------------------
CREATE OR REPLACE TABLE RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING (
    SOLD_TO_ORGANIZATION_NAME VARCHAR NOT NULL,
    SOLD_TO_CUSTOMER_NAME VARCHAR NOT NULL,
    CONSUMER_ACCOUNT_LOCATOR VARCHAR NOT NULL,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT UQ_ORG_ACCOUNT UNIQUE (SOLD_TO_ORGANIZATION_NAME, CONSUMER_ACCOUNT_LOCATOR)
);

INSERT INTO RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING
    (SOLD_TO_ORGANIZATION_NAME, SOLD_TO_CUSTOMER_NAME, CONSUMER_ACCOUNT_LOCATOR)
VALUES
    ('WSMUCXP',              'WSMUCXP',                      'WSMXXX0001'),
    ('TOKOPEDIA_DATA_ORG',   'PT Tokopedia',                 'TKP01234'),
    ('GOJEK_ANALYTICS_ORG',  'PT GoTo Gojek Tokopedia',      'GJK02345'),
    ('GRAB_PLATFORM_ORG',    'Grab Holdings Inc',            'GRB03456'),
    ('SEA_GROUP_ORG',        'Sea Limited',                  'SEA04567'),
    ('BUKALAPAK_ORG',        'PT Bukalapak.com',             'BKL05678'),
    ('TRAVELOKA_ORG',        'PT Trinusa Traveloka',         'TVK06789'),
    ('AKULAKU_ORG',          'PT Akulaku Silvrr Indonesia',  'AKL07890'),
    ('VNG_CORP_ORG',         'VNG Corporation',              'VNG08901'),
    ('LAZADA_ORG',           'Lazada Group SA',              'LZD09012'),
    ('AGODA_ORG',            'Agoda Company Pte Ltd',        'AGD10123'),
    ('BANGCHAK_ORG',         'Bangchak Corporation PCL',     'BCK11234'),
    ('MAYBANK_DIGITAL_ORG',  'Malayan Banking Berhad',       'MYB12345'),
    ('SINGTEL_ORG',          'Singapore Telecom Ltd',        'STL13456'),
    ('BCA_DIGITAL_ORG',      'PT Bank Central Asia Tbk',     'BCA14567'),
    ('DANA_FINTECH_ORG',     'PT Dana Indonesia',            'DNA15678');

--------------------------------------------------------------------
-- STEP 3: Markup rates table (max 5% enforced by CHECK constraint)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES (
    SOLD_TO_ORGANIZATION_NAME VARCHAR NOT NULL,
    MARKUP_PCT NUMBER(5,4) NOT NULL DEFAULT 0.0000,
    EFFECTIVE_FROM DATE NOT NULL DEFAULT CURRENT_DATE(),
    EFFECTIVE_TO DATE DEFAULT NULL,
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT CHK_MARKUP_MAX CHECK (MARKUP_PCT >= 0 AND MARKUP_PCT <= 0.05)
);

INSERT INTO RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES
    (SOLD_TO_ORGANIZATION_NAME, MARKUP_PCT, EFFECTIVE_FROM)
VALUES
    ('WSMUCXP',              0.0300, '2025-05-01'),  -- 3.0%
    ('TOKOPEDIA_DATA_ORG',   0.0200, '2025-05-01'),  -- 2.0%
    ('GOJEK_ANALYTICS_ORG',  0.0000, '2025-05-01'),  -- 0.0% (no markup)
    ('GRAB_PLATFORM_ORG',    0.0150, '2025-05-01'),  -- 1.5%
    ('SEA_GROUP_ORG',        0.0000, '2025-05-01'),  -- 0.0% (no markup)
    ('BUKALAPAK_ORG',        0.0500, '2025-05-01'),  -- 5.0% (max)
    ('TRAVELOKA_ORG',        0.0250, '2025-05-01'),  -- 2.5%
    ('AKULAKU_ORG',          0.0400, '2025-05-01'),  -- 4.0%
    ('VNG_CORP_ORG',         0.0350, '2025-05-01'),  -- 3.5%
    ('LAZADA_ORG',           0.0000, '2025-05-01'),  -- 0.0% (no markup)
    ('AGODA_ORG',            0.0100, '2025-05-01'),  -- 1.0%
    ('BANGCHAK_ORG',         0.0450, '2025-05-01'),  -- 4.5%
    ('MAYBANK_DIGITAL_ORG',  0.0000, '2025-05-01'),  -- 0.0% (no markup)
    ('SINGTEL_ORG',          0.0200, '2025-05-01'),  -- 2.0%
    ('BCA_DIGITAL_ORG',      0.0300, '2025-05-01'),  -- 3.0%
    ('DANA_FINTECH_ORG',     0.0500, '2025-05-01');  -- 5.0% (max)

--------------------------------------------------------------------
-- STEP 4: Secure views (row filtering + markup)
--------------------------------------------------------------------

-- 4a. PARTNER_CONTRACT_ITEMS
CREATE OR REPLACE SECURE VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_CONTRACT_ITEMS AS
SELECT
    c.ORGANIZATION_NAME,
    c.SOLD_TO_ORGANIZATION_NAME,
    c.SOLD_TO_CUSTOMER_NAME,
    c.SOLD_TO_PO_NUMBER,
    c.SOLD_TO_CONTRACT_NUMBER,
    c.START_DATE,
    c.END_DATE,
    c.EXPIRATION_DATE,
    c.CONTRACT_ITEM,
    c.CURRENCY,
    ROUND(c.AMOUNT * (1 + COALESCE(m.MARKUP_PCT, 0)), 4) AS AMOUNT,
    c.CONTRACT_MODIFIED_DATE
FROM RESELLER_BILLING_FINAL.BILLING.PARTNER_CONTRACT_ITEMS c
JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING a
    ON c.SOLD_TO_ORGANIZATION_NAME = a.SOLD_TO_ORGANIZATION_NAME
    AND a.IS_ACTIVE = TRUE
    AND a.CONSUMER_ACCOUNT_LOCATOR = CURRENT_ACCOUNT()
LEFT JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES m
    ON c.SOLD_TO_ORGANIZATION_NAME = m.SOLD_TO_ORGANIZATION_NAME
    AND m.IS_ACTIVE = TRUE
    AND CURRENT_DATE() >= m.EFFECTIVE_FROM
    AND (m.EFFECTIVE_TO IS NULL OR CURRENT_DATE() <= m.EFFECTIVE_TO);

-- 4b. PARTNER_RATE_SHEET_DAILY
CREATE OR REPLACE SECURE VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_RATE_SHEET_DAILY AS
SELECT
    r.ORGANIZATION_NAME,
    r.SOLD_TO_ORGANIZATION_NAME,
    r.SOLD_TO_CUSTOMER_NAME,
    r.SOLD_TO_PO_NUMBER,
    r.SOLD_TO_CONTRACT_NUMBER,
    r.DATE,
    r.ACCOUNT_NAME,
    r.ACCOUNT_LOCATOR,
    r.REGION,
    r.SERVICE_LEVEL,
    r.USAGE_TYPE,
    r.BILLING_TYPE,
    r.RATING_TYPE,
    r.SERVICE_TYPE,
    r.IS_ADJUSTMENT,
    r.CURRENCY,
    ROUND(r.EFFECTIVE_RATE * (1 + COALESCE(m.MARKUP_PCT, 0)), 2) AS EFFECTIVE_RATE
FROM RESELLER_BILLING_FINAL.BILLING.PARTNER_RATE_SHEET_DAILY r
JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING a
    ON r.SOLD_TO_ORGANIZATION_NAME = a.SOLD_TO_ORGANIZATION_NAME
    AND a.IS_ACTIVE = TRUE
    AND a.CONSUMER_ACCOUNT_LOCATOR = CURRENT_ACCOUNT()
LEFT JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES m
    ON r.SOLD_TO_ORGANIZATION_NAME = m.SOLD_TO_ORGANIZATION_NAME
    AND m.IS_ACTIVE = TRUE
    AND r.DATE >= m.EFFECTIVE_FROM
    AND (m.EFFECTIVE_TO IS NULL OR r.DATE <= m.EFFECTIVE_TO);

-- 4c. PARTNER_USAGE_IN_CURRENCY_DAILY
CREATE OR REPLACE SECURE VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY AS
SELECT
    u.ORGANIZATION_NAME,
    u.SOLD_TO_ORGANIZATION_NAME,
    u.SOLD_TO_CUSTOMER_NAME,
    u.SOLD_TO_PO_NUMBER,
    u.SOLD_TO_CONTRACT_NUMBER,
    u.ACCOUNT_NAME,
    u.ACCOUNT_LOCATOR,
    u.REGION,
    u.SERVICE_LEVEL,
    u.USAGE_DATE,
    u.USAGE_TYPE,
    u.CURRENCY,
    u.USAGE,
    ROUND(u.USAGE_IN_CURRENCY * (1 + COALESCE(m.MARKUP_PCT, 0)), 6) AS USAGE_IN_CURRENCY,
    u.BALANCE_SOURCE,
    u.BILLING_TYPE,
    u.RATING_TYPE,
    u.SERVICE_TYPE,
    u.IS_ADJUSTMENT
FROM RESELLER_BILLING_FINAL.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY u
JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING a
    ON u.SOLD_TO_ORGANIZATION_NAME = a.SOLD_TO_ORGANIZATION_NAME
    AND a.IS_ACTIVE = TRUE
    AND a.CONSUMER_ACCOUNT_LOCATOR = CURRENT_ACCOUNT()
LEFT JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES m
    ON u.SOLD_TO_ORGANIZATION_NAME = m.SOLD_TO_ORGANIZATION_NAME
    AND m.IS_ACTIVE = TRUE
    AND u.USAGE_DATE >= m.EFFECTIVE_FROM
    AND (m.EFFECTIVE_TO IS NULL OR u.USAGE_DATE <= m.EFFECTIVE_TO);

-- 4d. PARTNER_REMAINING_BALANCE_DAILY
CREATE OR REPLACE SECURE VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_REMAINING_BALANCE_DAILY AS
SELECT
    b.ORGANIZATION_NAME,
    b.SOLD_TO_ORGANIZATION_NAME,
    b.SOLD_TO_CUSTOMER_NAME,
    b.SOLD_TO_PO_NUMBER,
    b.SOLD_TO_CONTRACT_NUMBER,
    b.DATE,
    b.CURRENCY,
    ROUND(b.FREE_USAGE_BALANCE * (1 + COALESCE(m.MARKUP_PCT, 0)), 2) AS FREE_USAGE_BALANCE,
    ROUND(b.CAPACITY_BALANCE * (1 + COALESCE(m.MARKUP_PCT, 0)), 2) AS CAPACITY_BALANCE,
    ROUND(b.ON_DEMAND_CONSUMPTION_BALANCE * (1 + COALESCE(m.MARKUP_PCT, 0)), 2) AS ON_DEMAND_CONSUMPTION_BALANCE,
    ROUND(b.ROLLOVER_BALANCE * (1 + COALESCE(m.MARKUP_PCT, 0)), 2) AS ROLLOVER_BALANCE,
    ROUND(b.MARKETPLACE_CAPACITY_DRAWDOWN_BALANCE * (1 + COALESCE(m.MARKUP_PCT, 0)), 2) AS MARKETPLACE_CAPACITY_DRAWDOWN_BALANCE
FROM RESELLER_BILLING_FINAL.BILLING.PARTNER_REMAINING_BALANCE_DAILY b
JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING a
    ON b.SOLD_TO_ORGANIZATION_NAME = a.SOLD_TO_ORGANIZATION_NAME
    AND a.IS_ACTIVE = TRUE
    AND a.CONSUMER_ACCOUNT_LOCATOR = CURRENT_ACCOUNT()
LEFT JOIN RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES m
    ON b.SOLD_TO_ORGANIZATION_NAME = m.SOLD_TO_ORGANIZATION_NAME
    AND m.IS_ACTIVE = TRUE
    AND b.DATE >= m.EFFECTIVE_FROM
    AND (m.EFFECTIVE_TO IS NULL OR b.DATE <= m.EFFECTIVE_TO);

--------------------------------------------------------------------
-- STEP 5: Create share and grant privileges
--------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE SHARE RESELLER_BILLING_SHARE
    COMMENT = 'Reseller billing data share - per-customer secure views with markup';

GRANT USAGE ON DATABASE RESELLER_BILLING_FINAL TO SHARE RESELLER_BILLING_SHARE;
GRANT USAGE ON SCHEMA RESELLER_BILLING_FINAL.SHARED TO SHARE RESELLER_BILLING_SHARE;
GRANT SELECT ON VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_CONTRACT_ITEMS TO SHARE RESELLER_BILLING_SHARE;
GRANT SELECT ON VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_RATE_SHEET_DAILY TO SHARE RESELLER_BILLING_SHARE;
GRANT SELECT ON VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY TO SHARE RESELLER_BILLING_SHARE;
GRANT SELECT ON VIEW RESELLER_BILLING_FINAL.SHARED.PARTNER_REMAINING_BALANCE_DAILY TO SHARE RESELLER_BILLING_SHARE;

--------------------------------------------------------------------
-- STEP 6: Add consumer accounts to the share
--   Example: adding WSMUCXP (org WSMUCXP, account <CUSTOMER_ACCOUNT_NAME>)
--   Replace <CUSTOMER_ORG> and <CUSTOMER_ACCOUNT_NAME> with real values
--------------------------------------------------------------------
-- ALTER SHARE RESELLER_BILLING_SHARE ADD ACCOUNTS = <CUSTOMER_ORG>.<CUSTOMER_ACCOUNT_NAME>;
-- Example: ALTER SHARE RESELLER_BILLING_SHARE ADD ACCOUNTS = WSMUCXP.ACCTNAME123;

--------------------------------------------------------------------
-- STEP 7: Validation - simulate as consumer
--------------------------------------------------------------------
-- ALTER SESSION SET SIMULATED_DATA_SHARING_CONSUMER = '<CUSTOMER_ACCOUNT_LOCATOR>';
-- Example: ALTER SESSION SET SIMULATED_DATA_SHARING_CONSUMER = 'ABC12345';
-- SELECT * FROM RESELLER_BILLING_FINAL.SHARED.PARTNER_CONTRACT_ITEMS;
-- SELECT * FROM RESELLER_BILLING_FINAL.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY LIMIT 10;
-- ALTER SESSION UNSET SIMULATED_DATA_SHARING_CONSUMER;

--------------------------------------------------------------------
-- ================================================================
-- EXAMPLE: ONBOARDING A NEW CUSTOMER
-- ================================================================
-- When a new customer signs a contract with the reseller:
--
-- Scenario: "PT Tiket Com" from Indonesia signs up
--   - Org name: TIKET_COM_ORG
--   - Snowflake account locator: TKT99999
--   - Agreed markup: 2.5%
--
-- STEP A: Register the account mapping
-- ----------------------------------------------------------------
-- INSERT INTO RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING
--     (SOLD_TO_ORGANIZATION_NAME, SOLD_TO_CUSTOMER_NAME, CONSUMER_ACCOUNT_LOCATOR)
-- VALUES
--     ('TIKET_COM_ORG', 'PT Tiket Com', 'TKT99999');
--
-- STEP B: Set the markup rate
-- ----------------------------------------------------------------
-- INSERT INTO RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES
--     (SOLD_TO_ORGANIZATION_NAME, MARKUP_PCT, EFFECTIVE_FROM)
-- VALUES
--     ('TIKET_COM_ORG', 0.0250, CURRENT_DATE());
--
-- STEP C: Add account to the share (requires ACCOUNTADMIN)
-- ----------------------------------------------------------------
-- USE ROLE ACCOUNTADMIN;
-- ALTER SHARE RESELLER_BILLING_SHARE ADD ACCOUNTS = <org_name>.TKT99999;
--
-- STEP D: Validate before notifying customer
-- ----------------------------------------------------------------
-- ALTER SESSION SET SIMULATED_DATA_SHARING_CONSUMER = 'TKT99999';
-- SELECT * FROM RESELLER_BILLING_FINAL.SHARED.PARTNER_CONTRACT_ITEMS;
-- SELECT * FROM RESELLER_BILLING_FINAL.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY LIMIT 10;
-- ALTER SESSION UNSET SIMULATED_DATA_SHARING_CONSUMER;
--
-- That's it! No view changes, no ETL. The secure views automatically
-- pick up the new customer's data filtered and marked up.
-- ================================================================

--------------------------------------------------------------------
-- ================================================================
-- EXAMPLE: UPDATING MARKUP FOR AN EXISTING CUSTOMER
-- ================================================================
-- Scenario: Increase WSMUCXP markup from 3% to 4% starting Jul 1
--
-- STEP A: Expire the current rate
-- ----------------------------------------------------------------
-- UPDATE RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES
--    SET EFFECTIVE_TO = '2025-06-30',
--        UPDATED_AT = CURRENT_TIMESTAMP()
-- WHERE SOLD_TO_ORGANIZATION_NAME = 'WSMUCXP'
--   AND IS_ACTIVE = TRUE
--   AND EFFECTIVE_TO IS NULL;
--
-- STEP B: Insert the new rate
-- ----------------------------------------------------------------
-- INSERT INTO RESELLER_BILLING_FINAL.SHARING_CONFIG.MARKUP_RATES
--     (SOLD_TO_ORGANIZATION_NAME, MARKUP_PCT, EFFECTIVE_FROM)
-- VALUES
--     ('WSMUCXP', 0.0400, '2025-07-01');
--
-- Historical data keeps the old markup, new data gets the new rate.
-- ================================================================

--------------------------------------------------------------------
-- ================================================================
-- EXAMPLE: DEACTIVATING A CUSTOMER
-- ================================================================
-- Scenario: Bukalapak contract ends, revoke access
--
-- UPDATE RESELLER_BILLING_FINAL.SHARING_CONFIG.ACCOUNT_MAPPING
--    SET IS_ACTIVE = FALSE,
--        UPDATED_AT = CURRENT_TIMESTAMP()
-- WHERE SOLD_TO_ORGANIZATION_NAME = 'BUKALAPAK_ORG';
--
-- The secure views will immediately stop returning data for this
-- customer. Optionally also remove from share:
-- USE ROLE ACCOUNTADMIN;
-- ALTER SHARE RESELLER_BILLING_SHARE REMOVE ACCOUNTS = <org>.BKL05678;
-- ================================================================

--------------------------------------------------------------------
-- CONSUMER SIDE INSTRUCTIONS
-- ================================================================
-- On the consumer account (e.g. WSMUCXP / <CUSTOMER_ACCOUNT_NAME>):
--
-- USE ROLE ACCOUNTADMIN;
-- CREATE DATABASE RESELLER_BILLING FROM SHARE <YOUR_ORG>.<YOUR_ACCOUNT>.RESELLER_BILLING_SHARE;
-- Example: CREATE DATABASE RESELLER_BILLING FROM SHARE MYRESELLER_ORG.MYACCOUNT.RESELLER_BILLING_SHARE;
-- GRANT IMPORTED PRIVILEGES ON DATABASE RESELLER_BILLING TO ROLE <role>;
--
-- Then query as usual:
-- SELECT * FROM RESELLER_BILLING.SHARED.PARTNER_USAGE_IN_CURRENCY_DAILY;
-- ================================================================
