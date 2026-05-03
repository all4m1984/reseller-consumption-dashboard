--------------------------------------------------------------------
-- Reseller Billing Synthetic Data - Southeast Asia Customers
-- Database: RESELLER_BILLING_FINAL | Schema: BILLING
-- Date Range: 2025-05-03 to 2026-05-03 (1 year)
-- 16 Customers | 22 Accounts | ~$6.46M total spend
--------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS RESELLER_BILLING_FINAL;
CREATE SCHEMA IF NOT EXISTS RESELLER_BILLING_FINAL.BILLING;

--------------------------------------------------------------------
-- 1. PARTNER_CONTRACT_ITEMS
--------------------------------------------------------------------
CREATE OR REPLACE TABLE RESELLER_BILLING_FINAL.BILLING.PARTNER_CONTRACT_ITEMS (
    ORGANIZATION_NAME VARCHAR,
    SOLD_TO_ORGANIZATION_NAME VARCHAR,
    SOLD_TO_CUSTOMER_NAME VARCHAR,
    SOLD_TO_PO_NUMBER VARCHAR,
    SOLD_TO_CONTRACT_NUMBER VARCHAR,
    START_DATE DATE,
    END_DATE DATE,
    EXPIRATION_DATE DATE,
    CONTRACT_ITEM VARCHAR,
    CURRENCY VARCHAR,
    AMOUNT NUMBER(26,4),
    CONTRACT_MODIFIED_DATE DATE
);

INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_CONTRACT_ITEMS
WITH customers AS (
    SELECT column1 AS org_name, column2 AS cust_name, column3 AS po, column4 AS contract, column5 AS currency, column6 AS region_code, column7 AS capacity_amt, column8 AS free_amt
    FROM VALUES
        ('TOKOPEDIA_DATA_ORG',    'PT Tokopedia',              'PO-TKP-2025-001', 'CNT-TKP-2025-0001', 'USD', 'ID', 250000, 5000),
        ('GOJEK_ANALYTICS_ORG',   'PT GoTo Gojek Tokopedia',   'PO-GJK-2025-002', 'CNT-GJK-2025-0002', 'USD', 'ID', 400000, 8000),
        ('GRAB_PLATFORM_ORG',     'Grab Holdings Inc',         'PO-GRB-2025-003', 'CNT-GRB-2025-0003', 'USD', 'SG', 600000, 12000),
        ('SEA_GROUP_ORG',         'Sea Limited',               'PO-SEA-2025-004', 'CNT-SEA-2025-0004', 'USD', 'SG', 500000, 10000),
        ('BUKALAPAK_ORG',         'PT Bukalapak.com',          'PO-BKL-2025-005', 'CNT-BKL-2025-0005', 'USD', 'ID', 150000, 3000),
        ('TRAVELOKA_ORG',         'PT Trinusa Traveloka',      'PO-TVK-2025-006', 'CNT-TVK-2025-0006', 'USD', 'ID', 300000, 6000),
        ('AKULAKU_ORG',           'PT Akulaku Silvrr Indonesia','PO-AKL-2025-007', 'CNT-AKL-2025-0007', 'USD', 'ID', 120000, 2500),
        ('VNG_CORP_ORG',          'VNG Corporation',           'PO-VNG-2025-008', 'CNT-VNG-2025-0008', 'USD', 'VN', 180000, 3500),
        ('LAZADA_ORG',            'Lazada Group SA',           'PO-LZD-2025-009', 'CNT-LZD-2025-0009', 'USD', 'SG', 450000, 9000),
        ('AGODA_ORG',             'Agoda Company Pte Ltd',     'PO-AGD-2025-010', 'CNT-AGD-2025-0010', 'USD', 'TH', 350000, 7000),
        ('BANGCHAK_ORG',          'Bangchak Corporation PCL',  'PO-BCK-2025-011', 'CNT-BCK-2025-0011', 'USD', 'TH', 100000, 2000),
        ('MAYBANK_DIGITAL_ORG',   'Malayan Banking Berhad',    'PO-MYB-2025-012', 'CNT-MYB-2025-0012', 'USD', 'MY', 280000, 5500),
        ('SINGTEL_ORG',           'Singapore Telecom Ltd',     'PO-STL-2025-013', 'CNT-STL-2025-0013', 'USD', 'SG', 320000, 6500),
        ('BCA_DIGITAL_ORG',       'PT Bank Central Asia Tbk',  'PO-BCA-2025-014', 'CNT-BCA-2025-0014', 'USD', 'ID', 220000, 4500),
        ('DANA_FINTECH_ORG',      'PT Dana Indonesia',         'PO-DNA-2025-015', 'CNT-DNA-2025-0015', 'USD', 'ID', 130000, 2800)
)
SELECT
    'ASEAN_CLOUD_RESELLER' AS ORGANIZATION_NAME,
    org_name AS SOLD_TO_ORGANIZATION_NAME,
    cust_name AS SOLD_TO_CUSTOMER_NAME,
    po AS SOLD_TO_PO_NUMBER,
    contract AS SOLD_TO_CONTRACT_NUMBER,
    '2025-05-01'::DATE AS START_DATE,
    '2026-04-30'::DATE AS END_DATE,
    '2026-05-30'::DATE AS EXPIRATION_DATE,
    item.value::VARCHAR AS CONTRACT_ITEM,
    currency AS CURRENCY,
    CASE item.value::VARCHAR
        WHEN 'capacity' THEN capacity_amt
        WHEN 'free usage' THEN free_amt
    END AS AMOUNT,
    '2025-04-15'::DATE AS CONTRACT_MODIFIED_DATE
FROM customers,
LATERAL FLATTEN(input => ARRAY_CONSTRUCT('capacity', 'free usage')) item;

--------------------------------------------------------------------
-- 2. PARTNER_RATE_SHEET_DAILY
--------------------------------------------------------------------
CREATE OR REPLACE TABLE RESELLER_BILLING_FINAL.BILLING.PARTNER_RATE_SHEET_DAILY (
    ORGANIZATION_NAME VARCHAR,
    SOLD_TO_ORGANIZATION_NAME VARCHAR,
    SOLD_TO_CUSTOMER_NAME VARCHAR,
    SOLD_TO_PO_NUMBER VARCHAR,
    SOLD_TO_CONTRACT_NUMBER VARCHAR,
    DATE DATE,
    ACCOUNT_NAME VARCHAR,
    ACCOUNT_LOCATOR VARCHAR,
    REGION VARCHAR,
    SERVICE_LEVEL VARCHAR,
    USAGE_TYPE VARCHAR,
    BILLING_TYPE VARCHAR,
    RATING_TYPE VARCHAR,
    SERVICE_TYPE VARCHAR,
    IS_ADJUSTMENT BOOLEAN,
    CURRENCY VARCHAR,
    EFFECTIVE_RATE NUMBER(38,2)
);

INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_RATE_SHEET_DAILY
WITH customers AS (
    SELECT column1 AS org_name, column2 AS cust_name, column3 AS po, column4 AS contract,
           column5 AS acct_name, column6 AS acct_locator, column7 AS region, column8 AS svc_level
    FROM VALUES
        ('TOKOPEDIA_DATA_ORG','PT Tokopedia','PO-TKP-2025-001','CNT-TKP-2025-0001','TOKOPEDIA_PROD','TKP01234','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('TOKOPEDIA_DATA_ORG','PT Tokopedia','PO-TKP-2025-001','CNT-TKP-2025-0001','TOKOPEDIA_DEV','TKP01235','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('GOJEK_ANALYTICS_ORG','PT GoTo Gojek Tokopedia','PO-GJK-2025-002','CNT-GJK-2025-0002','GOJEK_ANALYTICS','GJK02345','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('GOJEK_ANALYTICS_ORG','PT GoTo Gojek Tokopedia','PO-GJK-2025-002','CNT-GJK-2025-0002','GOJEK_PROD','GJK02346','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('GRAB_PLATFORM_ORG','Grab Holdings Inc','PO-GRB-2025-003','CNT-GRB-2025-0003','GRAB_PLATFORM','GRB03456','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('GRAB_PLATFORM_ORG','Grab Holdings Inc','PO-GRB-2025-003','CNT-GRB-2025-0003','GRAB_ML','GRB03457','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('SEA_GROUP_ORG','Sea Limited','PO-SEA-2025-004','CNT-SEA-2025-0004','SEA_SHOPEE','SEA04567','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('SEA_GROUP_ORG','Sea Limited','PO-SEA-2025-004','CNT-SEA-2025-0004','SEA_GARENA','SEA04568','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('BUKALAPAK_ORG','PT Bukalapak.com','PO-BKL-2025-005','CNT-BKL-2025-0005','BUKALAPAK_MAIN','BKL05678','AWS_AP_SOUTHEAST_1','Standard'),
        ('TRAVELOKA_ORG','PT Trinusa Traveloka','PO-TVK-2025-006','CNT-TVK-2025-0006','TRAVELOKA_PROD','TVK06789','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('TRAVELOKA_ORG','PT Trinusa Traveloka','PO-TVK-2025-006','CNT-TVK-2025-0006','TRAVELOKA_STAGING','TVK06790','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('AKULAKU_ORG','PT Akulaku Silvrr Indonesia','PO-AKL-2025-007','CNT-AKL-2025-0007','AKULAKU_FINTECH','AKL07890','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('VNG_CORP_ORG','VNG Corporation','PO-VNG-2025-008','CNT-VNG-2025-0008','VNG_GAMING','VNG08901','AWS_AP_SOUTHEAST_1','Standard'),
        ('LAZADA_ORG','Lazada Group SA','PO-LZD-2025-009','CNT-LZD-2025-0009','LAZADA_ECOMMERCE','LZD09012','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('LAZADA_ORG','Lazada Group SA','PO-LZD-2025-009','CNT-LZD-2025-0009','LAZADA_LOGISTICS','LZD09013','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('AGODA_ORG','Agoda Company Pte Ltd','PO-AGD-2025-010','CNT-AGD-2025-0010','AGODA_TRAVEL','AGD10123','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('BANGCHAK_ORG','Bangchak Corporation PCL','PO-BCK-2025-011','CNT-BCK-2025-0011','BANGCHAK_ENERGY','BCK11234','AWS_AP_SOUTHEAST_1','Standard'),
        ('MAYBANK_DIGITAL_ORG','Malayan Banking Berhad','PO-MYB-2025-012','CNT-MYB-2025-0012','MAYBANK_DIGITAL','MYB12345','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('SINGTEL_ORG','Singapore Telecom Ltd','PO-STL-2025-013','CNT-STL-2025-0013','SINGTEL_DATA','STL13456','AWS_AP_SOUTHEAST_1','Enterprise'),
        ('BCA_DIGITAL_ORG','PT Bank Central Asia Tbk','PO-BCA-2025-014','CNT-BCA-2025-0014','BCA_DIGITAL','BCA14567','AWS_AP_SOUTHEAST_1','Business Critical'),
        ('DANA_FINTECH_ORG','PT Dana Indonesia','PO-DNA-2025-015','CNT-DNA-2025-0015','DANA_PAYMENTS','DNA15678','AWS_AP_SOUTHEAST_1','Enterprise')
),
date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) <= '2026-05-03'::DATE
),
service_types AS (
    SELECT column1 AS usage_type, column2 AS billing_type, column3 AS rating_type, column4 AS service_type, column5 AS rate
    FROM VALUES
        ('compute','consumption','compute','WAREHOUSE_METERING', 3.00),
        ('cloud services','consumption','compute','CLOUD_SERVICES', 3.00),
        ('storage','consumption','storage','STORAGE', 23.00),
        ('automatic clustering','consumption','compute','AUTOMATIC_CLUSTERING', 3.00),
        ('serverless tasks','consumption','compute','SERVERLESS_TASK', 3.00),
        ('snowpipe','consumption','compute','SNOWPIPE', 3.00),
        ('data transfer','consumption','data_transfer','DATA_TRANSFER', 0.02)
)
SELECT
    'ASEAN_CLOUD_RESELLER' AS ORGANIZATION_NAME,
    c.org_name,
    c.cust_name,
    c.po,
    c.contract,
    d.dt,
    c.acct_name,
    c.acct_locator,
    c.region,
    c.svc_level,
    s.usage_type,
    s.billing_type,
    s.rating_type,
    s.service_type,
    FALSE AS IS_ADJUSTMENT,
    'USD' AS CURRENCY,
    CASE
        WHEN c.svc_level = 'Business Critical' THEN s.rate * 1.60
        WHEN c.svc_level = 'Enterprise' THEN s.rate * 1.20
        ELSE s.rate
    END AS EFFECTIVE_RATE
FROM customers c
CROSS JOIN date_spine d
CROSS JOIN service_types s;

--------------------------------------------------------------------
-- 3. PARTNER_USAGE_IN_CURRENCY_DAILY
--------------------------------------------------------------------
CREATE OR REPLACE TABLE RESELLER_BILLING_FINAL.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY (
    ORGANIZATION_NAME VARCHAR,
    SOLD_TO_ORGANIZATION_NAME VARCHAR,
    SOLD_TO_CUSTOMER_NAME VARCHAR,
    SOLD_TO_PO_NUMBER VARCHAR,
    SOLD_TO_CONTRACT_NUMBER VARCHAR,
    ACCOUNT_NAME VARCHAR,
    ACCOUNT_LOCATOR VARCHAR,
    REGION VARCHAR,
    SERVICE_LEVEL VARCHAR,
    USAGE_DATE DATE,
    USAGE_TYPE VARCHAR,
    CURRENCY VARCHAR,
    USAGE NUMBER(38,6),
    USAGE_IN_CURRENCY NUMBER(38,6),
    BALANCE_SOURCE VARCHAR,
    BILLING_TYPE VARCHAR,
    RATING_TYPE VARCHAR,
    SERVICE_TYPE VARCHAR,
    IS_ADJUSTMENT BOOLEAN
);

INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY
WITH customers AS (
    SELECT column1 AS org_name, column2 AS cust_name, column3 AS po, column4 AS contract,
           column5 AS acct_name, column6 AS acct_locator, column7 AS region, column8 AS svc_level,
           column9 AS base_compute, column10 AS base_storage, column11 AS base_cloud_svc
    FROM VALUES
        ('TOKOPEDIA_DATA_ORG','PT Tokopedia','PO-TKP-2025-001','CNT-TKP-2025-0001','TOKOPEDIA_PROD','TKP01234','AWS_AP_SOUTHEAST_1','Enterprise', 85.0, 15.0, 12.0),
        ('TOKOPEDIA_DATA_ORG','PT Tokopedia','PO-TKP-2025-001','CNT-TKP-2025-0001','TOKOPEDIA_DEV','TKP01235','AWS_AP_SOUTHEAST_1','Enterprise', 25.0, 5.0, 4.0),
        ('GOJEK_ANALYTICS_ORG','PT GoTo Gojek Tokopedia','PO-GJK-2025-002','CNT-GJK-2025-0002','GOJEK_ANALYTICS','GJK02345','AWS_AP_SOUTHEAST_1','Business Critical', 140.0, 25.0, 20.0),
        ('GOJEK_ANALYTICS_ORG','PT GoTo Gojek Tokopedia','PO-GJK-2025-002','CNT-GJK-2025-0002','GOJEK_PROD','GJK02346','AWS_AP_SOUTHEAST_1','Business Critical', 110.0, 20.0, 16.0),
        ('GRAB_PLATFORM_ORG','Grab Holdings Inc','PO-GRB-2025-003','CNT-GRB-2025-0003','GRAB_PLATFORM','GRB03456','AWS_AP_SOUTHEAST_1','Business Critical', 200.0, 35.0, 28.0),
        ('GRAB_PLATFORM_ORG','Grab Holdings Inc','PO-GRB-2025-003','CNT-GRB-2025-0003','GRAB_ML','GRB03457','AWS_AP_SOUTHEAST_1','Business Critical', 120.0, 18.0, 15.0),
        ('SEA_GROUP_ORG','Sea Limited','PO-SEA-2025-004','CNT-SEA-2025-0004','SEA_SHOPEE','SEA04567','AWS_AP_SOUTHEAST_1','Enterprise', 170.0, 30.0, 24.0),
        ('SEA_GROUP_ORG','Sea Limited','PO-SEA-2025-004','CNT-SEA-2025-0004','SEA_GARENA','SEA04568','AWS_AP_SOUTHEAST_1','Enterprise', 90.0, 12.0, 10.0),
        ('BUKALAPAK_ORG','PT Bukalapak.com','PO-BKL-2025-005','CNT-BKL-2025-0005','BUKALAPAK_MAIN','BKL05678','AWS_AP_SOUTHEAST_1','Standard', 45.0, 8.0, 6.0),
        ('TRAVELOKA_ORG','PT Trinusa Traveloka','PO-TVK-2025-006','CNT-TVK-2025-0006','TRAVELOKA_PROD','TVK06789','AWS_AP_SOUTHEAST_1','Enterprise', 100.0, 18.0, 14.0),
        ('TRAVELOKA_ORG','PT Trinusa Traveloka','PO-TVK-2025-006','CNT-TVK-2025-0006','TRAVELOKA_STAGING','TVK06790','AWS_AP_SOUTHEAST_1','Enterprise', 30.0, 4.0, 3.0),
        ('AKULAKU_ORG','PT Akulaku Silvrr Indonesia','PO-AKL-2025-007','CNT-AKL-2025-0007','AKULAKU_FINTECH','AKL07890','AWS_AP_SOUTHEAST_1','Enterprise', 40.0, 7.0, 5.0),
        ('VNG_CORP_ORG','VNG Corporation','PO-VNG-2025-008','CNT-VNG-2025-0008','VNG_GAMING','VNG08901','AWS_AP_SOUTHEAST_1','Standard', 55.0, 10.0, 8.0),
        ('LAZADA_ORG','Lazada Group SA','PO-LZD-2025-009','CNT-LZD-2025-0009','LAZADA_ECOMMERCE','LZD09012','AWS_AP_SOUTHEAST_1','Enterprise', 150.0, 25.0, 20.0),
        ('LAZADA_ORG','Lazada Group SA','PO-LZD-2025-009','CNT-LZD-2025-0009','LAZADA_LOGISTICS','LZD09013','AWS_AP_SOUTHEAST_1','Enterprise', 60.0, 10.0, 8.0),
        ('AGODA_ORG','Agoda Company Pte Ltd','PO-AGD-2025-010','CNT-AGD-2025-0010','AGODA_TRAVEL','AGD10123','AWS_AP_SOUTHEAST_1','Business Critical', 130.0, 22.0, 18.0),
        ('BANGCHAK_ORG','Bangchak Corporation PCL','PO-BCK-2025-011','CNT-BCK-2025-0011','BANGCHAK_ENERGY','BCK11234','AWS_AP_SOUTHEAST_1','Standard', 30.0, 5.0, 4.0),
        ('MAYBANK_DIGITAL_ORG','Malayan Banking Berhad','PO-MYB-2025-012','CNT-MYB-2025-0012','MAYBANK_DIGITAL','MYB12345','AWS_AP_SOUTHEAST_1','Business Critical', 95.0, 16.0, 13.0),
        ('SINGTEL_ORG','Singapore Telecom Ltd','PO-STL-2025-013','CNT-STL-2025-0013','SINGTEL_DATA','STL13456','AWS_AP_SOUTHEAST_1','Enterprise', 105.0, 18.0, 14.0),
        ('BCA_DIGITAL_ORG','PT Bank Central Asia Tbk','PO-BCA-2025-014','CNT-BCA-2025-0014','BCA_DIGITAL','BCA14567','AWS_AP_SOUTHEAST_1','Business Critical', 75.0, 13.0, 10.0),
        ('DANA_FINTECH_ORG','PT Dana Indonesia','PO-DNA-2025-015','CNT-DNA-2025-0015','DANA_PAYMENTS','DNA15678','AWS_AP_SOUTHEAST_1','Enterprise', 42.0, 7.0, 5.5)
),
date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) <= '2026-05-03'::DATE
),
service_types AS (
    SELECT column1 AS usage_type, column2 AS billing_type, column3 AS rating_type, column4 AS service_type, column5 AS base_idx
    FROM VALUES
        ('compute','consumption','compute','WAREHOUSE_METERING', 1),
        ('cloud services','consumption','compute','CLOUD_SERVICES', 3),
        ('storage','consumption','storage','STORAGE', 2),
        ('automatic clustering','consumption','compute','AUTOMATIC_CLUSTERING', 4),
        ('serverless tasks','consumption','compute','SERVERLESS_TASK', 5),
        ('snowpipe','consumption','compute','SNOWPIPE', 6),
        ('data transfer','consumption','data_transfer','DATA_TRANSFER', 7)
),
raw_usage AS (
    SELECT
        c.*,
        d.dt,
        s.usage_type, s.billing_type, s.rating_type, s.service_type, s.base_idx,
        CASE s.base_idx
            WHEN 1 THEN c.base_compute * (0.7 + (HASH(c.acct_name || d.dt::VARCHAR || '1') % 60) / 100.0)
                        * (CASE DAYOFWEEK(d.dt) WHEN 0 THEN 0.4 WHEN 6 THEN 0.5 ELSE 1.0 END)
                        * (1 + (DATEDIFF(MONTH, '2025-05-03', d.dt) * 0.02))
            WHEN 2 THEN c.base_storage * (0.9 + (HASH(c.acct_name || d.dt::VARCHAR || '2') % 20) / 100.0)
                        * (1 + (DATEDIFF(MONTH, '2025-05-03', d.dt) * 0.03))
            WHEN 3 THEN c.base_cloud_svc * (0.6 + (HASH(c.acct_name || d.dt::VARCHAR || '3') % 80) / 100.0)
                        * (CASE DAYOFWEEK(d.dt) WHEN 0 THEN 0.3 WHEN 6 THEN 0.4 ELSE 1.0 END)
            WHEN 4 THEN c.base_compute * 0.08 * (0.5 + (HASH(c.acct_name || d.dt::VARCHAR || '4') % 100) / 100.0)
            WHEN 5 THEN c.base_compute * 0.12 * (0.4 + (HASH(c.acct_name || d.dt::VARCHAR || '5') % 120) / 100.0)
            WHEN 6 THEN c.base_compute * 0.06 * (0.3 + (HASH(c.acct_name || d.dt::VARCHAR || '6') % 140) / 100.0)
            WHEN 7 THEN c.base_compute * 0.02 * (0.2 + (HASH(c.acct_name || d.dt::VARCHAR || '7') % 160) / 100.0)
        END AS credit_usage,
        CASE
            WHEN s.rating_type = 'compute' THEN
                CASE WHEN c.svc_level = 'Business Critical' THEN 4.80
                     WHEN c.svc_level = 'Enterprise' THEN 3.60
                     ELSE 3.00 END
            WHEN s.rating_type = 'storage' THEN
                CASE WHEN c.svc_level = 'Business Critical' THEN 36.80
                     WHEN c.svc_level = 'Enterprise' THEN 27.60
                     ELSE 23.00 END
            ELSE
                CASE WHEN c.svc_level = 'Business Critical' THEN 0.032
                     WHEN c.svc_level = 'Enterprise' THEN 0.024
                     ELSE 0.020 END
        END AS eff_rate
    FROM customers c
    CROSS JOIN date_spine d
    CROSS JOIN service_types s
)
SELECT
    'ASEAN_CLOUD_RESELLER' AS ORGANIZATION_NAME,
    org_name AS SOLD_TO_ORGANIZATION_NAME,
    cust_name AS SOLD_TO_CUSTOMER_NAME,
    po AS SOLD_TO_PO_NUMBER,
    contract AS SOLD_TO_CONTRACT_NUMBER,
    acct_name AS ACCOUNT_NAME,
    acct_locator AS ACCOUNT_LOCATOR,
    region AS REGION,
    svc_level AS SERVICE_LEVEL,
    dt AS USAGE_DATE,
    usage_type AS USAGE_TYPE,
    'USD' AS CURRENCY,
    ROUND(credit_usage, 6) AS USAGE,
    ROUND(credit_usage * eff_rate, 6) AS USAGE_IN_CURRENCY,
    'capacity' AS BALANCE_SOURCE,
    billing_type AS BILLING_TYPE,
    rating_type AS RATING_TYPE,
    service_type AS SERVICE_TYPE,
    FALSE AS IS_ADJUSTMENT
FROM raw_usage;

--------------------------------------------------------------------
-- 4. PARTNER_REMAINING_BALANCE_DAILY
--    (depends on PARTNER_USAGE_IN_CURRENCY_DAILY being populated)
--------------------------------------------------------------------
CREATE OR REPLACE TABLE RESELLER_BILLING_FINAL.BILLING.PARTNER_REMAINING_BALANCE_DAILY (
    ORGANIZATION_NAME VARCHAR,
    SOLD_TO_ORGANIZATION_NAME VARCHAR,
    SOLD_TO_CUSTOMER_NAME VARCHAR,
    SOLD_TO_PO_NUMBER VARCHAR,
    SOLD_TO_CONTRACT_NUMBER VARCHAR,
    DATE DATE,
    CURRENCY VARCHAR,
    FREE_USAGE_BALANCE NUMBER(38,2),
    CAPACITY_BALANCE NUMBER(38,2),
    ON_DEMAND_CONSUMPTION_BALANCE NUMBER(38,2),
    ROLLOVER_BALANCE NUMBER(38,2),
    MARKETPLACE_CAPACITY_DRAWDOWN_BALANCE NUMBER(38,2)
);

INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_REMAINING_BALANCE_DAILY
WITH contracts AS (
    SELECT column1 AS org_name, column2 AS cust_name, column3 AS po, column4 AS contract,
           column5 AS capacity_amt, column6 AS free_amt, column7 AS rollover_amt
    FROM VALUES
        ('TOKOPEDIA_DATA_ORG','PT Tokopedia','PO-TKP-2025-001','CNT-TKP-2025-0001', 250000, 5000, 12000),
        ('GOJEK_ANALYTICS_ORG','PT GoTo Gojek Tokopedia','PO-GJK-2025-002','CNT-GJK-2025-0002', 400000, 8000, 20000),
        ('GRAB_PLATFORM_ORG','Grab Holdings Inc','PO-GRB-2025-003','CNT-GRB-2025-0003', 600000, 12000, 30000),
        ('SEA_GROUP_ORG','Sea Limited','PO-SEA-2025-004','CNT-SEA-2025-0004', 500000, 10000, 25000),
        ('BUKALAPAK_ORG','PT Bukalapak.com','PO-BKL-2025-005','CNT-BKL-2025-0005', 150000, 3000, 7000),
        ('TRAVELOKA_ORG','PT Trinusa Traveloka','PO-TVK-2025-006','CNT-TVK-2025-0006', 300000, 6000, 15000),
        ('AKULAKU_ORG','PT Akulaku Silvrr Indonesia','PO-AKL-2025-007','CNT-AKL-2025-0007', 120000, 2500, 6000),
        ('VNG_CORP_ORG','VNG Corporation','PO-VNG-2025-008','CNT-VNG-2025-0008', 180000, 3500, 9000),
        ('LAZADA_ORG','Lazada Group SA','PO-LZD-2025-009','CNT-LZD-2025-0009', 450000, 9000, 22000),
        ('AGODA_ORG','Agoda Company Pte Ltd','PO-AGD-2025-010','CNT-AGD-2025-0010', 350000, 7000, 18000),
        ('BANGCHAK_ORG','Bangchak Corporation PCL','PO-BCK-2025-011','CNT-BCK-2025-0011', 100000, 2000, 5000),
        ('MAYBANK_DIGITAL_ORG','Malayan Banking Berhad','PO-MYB-2025-012','CNT-MYB-2025-0012', 280000, 5500, 14000),
        ('SINGTEL_ORG','Singapore Telecom Ltd','PO-STL-2025-013','CNT-STL-2025-0013', 320000, 6500, 16000),
        ('BCA_DIGITAL_ORG','PT Bank Central Asia Tbk','PO-BCA-2025-014','CNT-BCA-2025-0014', 220000, 4500, 11000),
        ('DANA_FINTECH_ORG','PT Dana Indonesia','PO-DNA-2025-015','CNT-DNA-2025-0015', 130000, 2800, 6500)
),
date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) <= '2026-05-03'::DATE
),
daily_spend AS (
    SELECT
        SOLD_TO_CONTRACT_NUMBER,
        USAGE_DATE,
        SUM(USAGE_IN_CURRENCY) AS daily_total
    FROM RESELLER_BILLING_FINAL.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY
    GROUP BY SOLD_TO_CONTRACT_NUMBER, USAGE_DATE
),
cumulative AS (
    SELECT
        c.org_name, c.cust_name, c.po, c.contract,
        c.capacity_amt, c.free_amt, c.rollover_amt,
        d.dt,
        COALESCE(ds.daily_total, 0) AS daily_total,
        SUM(COALESCE(ds.daily_total, 0)) OVER (PARTITION BY c.contract ORDER BY d.dt ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_spend
    FROM contracts c
    CROSS JOIN date_spine d
    LEFT JOIN daily_spend ds ON ds.SOLD_TO_CONTRACT_NUMBER = c.contract AND ds.USAGE_DATE = d.dt
)
SELECT
    'ASEAN_CLOUD_RESELLER' AS ORGANIZATION_NAME,
    org_name,
    cust_name,
    po,
    contract,
    dt AS DATE,
    'USD' AS CURRENCY,
    GREATEST(free_amt - LEAST(cum_spend, free_amt), 0) AS FREE_USAGE_BALANCE,
    GREATEST(capacity_amt - GREATEST(cum_spend - free_amt, 0), 0) AS CAPACITY_BALANCE,
    CASE WHEN cum_spend > (free_amt + capacity_amt + rollover_amt)
         THEN -1 * (cum_spend - free_amt - capacity_amt - rollover_amt)
         ELSE 0 END AS ON_DEMAND_CONSUMPTION_BALANCE,
    GREATEST(rollover_amt - GREATEST(cum_spend - free_amt - capacity_amt, 0), 0) AS ROLLOVER_BALANCE,
    GREATEST(capacity_amt - GREATEST(cum_spend - free_amt, 0), 0) * 0.10 AS MARKETPLACE_CAPACITY_DRAWDOWN_BALANCE
FROM cumulative;

--------------------------------------------------------------------
-- 5. WSMUCXP / WSMUCXP_DEMO ACCOUNT DATA (all 4 tables)
--------------------------------------------------------------------

-- 5a. Contract Items
INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_CONTRACT_ITEMS
SELECT
    'ASEAN_CLOUD_RESELLER' AS ORGANIZATION_NAME,
    'WSMUCXP' AS SOLD_TO_ORGANIZATION_NAME,
    'WSMUCXP' AS SOLD_TO_CUSTOMER_NAME,
    'PO-WSM-2025-016' AS SOLD_TO_PO_NUMBER,
    'CNT-WSM-2025-0016' AS SOLD_TO_CONTRACT_NUMBER,
    '2025-05-01'::DATE AS START_DATE,
    '2026-04-30'::DATE AS END_DATE,
    '2026-05-30'::DATE AS EXPIRATION_DATE,
    item.value::VARCHAR AS CONTRACT_ITEM,
    'USD' AS CURRENCY,
    CASE item.value::VARCHAR
        WHEN 'capacity' THEN 200000
        WHEN 'free usage' THEN 4000
    END AS AMOUNT,
    '2025-04-15'::DATE AS CONTRACT_MODIFIED_DATE
FROM TABLE(FLATTEN(input => ARRAY_CONSTRUCT('capacity', 'free usage'))) item;

-- 5b. Rate Sheet Daily
INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_RATE_SHEET_DAILY
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) <= '2026-05-03'::DATE
),
service_types AS (
    SELECT column1 AS usage_type, column2 AS billing_type, column3 AS rating_type, column4 AS service_type, column5 AS rate
    FROM VALUES
        ('compute','consumption','compute','WAREHOUSE_METERING', 3.00),
        ('cloud services','consumption','compute','CLOUD_SERVICES', 3.00),
        ('storage','consumption','storage','STORAGE', 23.00),
        ('automatic clustering','consumption','compute','AUTOMATIC_CLUSTERING', 3.00),
        ('serverless tasks','consumption','compute','SERVERLESS_TASK', 3.00),
        ('snowpipe','consumption','compute','SNOWPIPE', 3.00),
        ('data transfer','consumption','data_transfer','DATA_TRANSFER', 0.02)
)
SELECT
    'ASEAN_CLOUD_RESELLER', 'WSMUCXP', 'WSMUCXP',
    'PO-WSM-2025-016', 'CNT-WSM-2025-0016',
    d.dt, 'WSMUCXP_DEMO', 'WSMXXX0001', 'AWS_AP_SOUTHEAST_1', 'Enterprise',
    s.usage_type, s.billing_type, s.rating_type, s.service_type,
    FALSE, 'USD', s.rate * 1.20
FROM date_spine d
CROSS JOIN service_types s;

-- 5c. Usage in Currency Daily
INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) <= '2026-05-03'::DATE
),
service_types AS (
    SELECT column1 AS usage_type, column2 AS billing_type, column3 AS rating_type, column4 AS service_type, column5 AS base_idx
    FROM VALUES
        ('compute','consumption','compute','WAREHOUSE_METERING', 1),
        ('cloud services','consumption','compute','CLOUD_SERVICES', 3),
        ('storage','consumption','storage','STORAGE', 2),
        ('automatic clustering','consumption','compute','AUTOMATIC_CLUSTERING', 4),
        ('serverless tasks','consumption','compute','SERVERLESS_TASK', 5),
        ('snowpipe','consumption','compute','SNOWPIPE', 6),
        ('data transfer','consumption','data_transfer','DATA_TRANSFER', 7)
),
raw_usage AS (
    SELECT
        d.dt, s.usage_type, s.billing_type, s.rating_type, s.service_type, s.base_idx,
        CASE s.base_idx
            WHEN 1 THEN 65.0 * (0.7 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '1') % 60) / 100.0)
                        * (CASE DAYOFWEEK(d.dt) WHEN 0 THEN 0.4 WHEN 6 THEN 0.5 ELSE 1.0 END)
                        * (1 + (DATEDIFF(MONTH, '2025-05-03', d.dt) * 0.02))
            WHEN 2 THEN 12.0 * (0.9 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '2') % 20) / 100.0)
                        * (1 + (DATEDIFF(MONTH, '2025-05-03', d.dt) * 0.03))
            WHEN 3 THEN 9.0 * (0.6 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '3') % 80) / 100.0)
                        * (CASE DAYOFWEEK(d.dt) WHEN 0 THEN 0.3 WHEN 6 THEN 0.4 ELSE 1.0 END)
            WHEN 4 THEN 65.0 * 0.08 * (0.5 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '4') % 100) / 100.0)
            WHEN 5 THEN 65.0 * 0.12 * (0.4 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '5') % 120) / 100.0)
            WHEN 6 THEN 65.0 * 0.06 * (0.3 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '6') % 140) / 100.0)
            WHEN 7 THEN 65.0 * 0.02 * (0.2 + (HASH('WSMUCXP_DEMO' || d.dt::VARCHAR || '7') % 160) / 100.0)
        END AS credit_usage,
        CASE
            WHEN s.rating_type = 'compute' THEN 3.60
            WHEN s.rating_type = 'storage' THEN 27.60
            ELSE 0.024
        END AS eff_rate
    FROM date_spine d
    CROSS JOIN service_types s
)
SELECT
    'ASEAN_CLOUD_RESELLER', 'WSMUCXP', 'WSMUCXP',
    'PO-WSM-2025-016', 'CNT-WSM-2025-0016',
    'WSMUCXP_DEMO', 'WSMXXX0001', 'AWS_AP_SOUTHEAST_1', 'Enterprise',
    dt, usage_type, 'USD',
    ROUND(credit_usage, 6), ROUND(credit_usage * eff_rate, 6),
    'capacity', billing_type, rating_type, service_type, FALSE
FROM raw_usage;

-- 5d. Remaining Balance Daily
INSERT INTO RESELLER_BILLING_FINAL.BILLING.PARTNER_REMAINING_BALANCE_DAILY
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) AS dt
    FROM TABLE(GENERATOR(ROWCOUNT => 366))
    WHERE DATEADD(DAY, SEQ4(), '2025-05-03'::DATE) <= '2026-05-03'::DATE
),
daily_spend AS (
    SELECT USAGE_DATE, SUM(USAGE_IN_CURRENCY) AS daily_total
    FROM RESELLER_BILLING_FINAL.BILLING.PARTNER_USAGE_IN_CURRENCY_DAILY
    WHERE SOLD_TO_CONTRACT_NUMBER = 'CNT-WSM-2025-0016'
    GROUP BY USAGE_DATE
),
cumulative AS (
    SELECT
        d.dt,
        COALESCE(ds.daily_total, 0) AS daily_total,
        SUM(COALESCE(ds.daily_total, 0)) OVER (ORDER BY d.dt ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_spend
    FROM date_spine d
    LEFT JOIN daily_spend ds ON ds.USAGE_DATE = d.dt
)
SELECT
    'ASEAN_CLOUD_RESELLER', 'WSMUCXP', 'WSMUCXP',
    'PO-WSM-2025-016', 'CNT-WSM-2025-0016',
    dt, 'USD',
    GREATEST(4000 - LEAST(cum_spend, 4000), 0),
    GREATEST(200000 - GREATEST(cum_spend - 4000, 0), 0),
    CASE WHEN cum_spend > (4000 + 200000 + 10000)
         THEN -1 * (cum_spend - 4000 - 200000 - 10000)
         ELSE 0 END,
    GREATEST(10000 - GREATEST(cum_spend - 4000 - 200000, 0), 0),
    GREATEST(200000 - GREATEST(cum_spend - 4000, 0), 0) * 0.10
FROM cumulative;
