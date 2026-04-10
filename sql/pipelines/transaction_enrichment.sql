-- =============================================================
-- SLS-2: Real-time Transaction Enrichment Pipeline
-- Streams & Tasks to enrich raw transactions with customer
-- and merchant reference data
-- Status: IN PROGRESS — enrichment logic TODO
-- =============================================================

USE DATABASE ANZ_BANKING;
USE SCHEMA PAYMENTS;

-- Source table: raw transactions landing from core banking
CREATE TABLE IF NOT EXISTS RAW_TRANSACTIONS (
    TRANSACTION_ID      VARCHAR(36)     NOT NULL,
    ACCOUNT_ID          VARCHAR(20)     NOT NULL,
    MERCHANT_ID         VARCHAR(20),
    AMOUNT              NUMBER(18,2)    NOT NULL,
    CURRENCY            VARCHAR(3)      DEFAULT 'NZD',
    TRANSACTION_TYPE    VARCHAR(20),
    TRANSACTION_TS      TIMESTAMP_NTZ   NOT NULL,
    CHANNEL             VARCHAR(20),
    STATUS              VARCHAR(10)     DEFAULT 'PENDING',
    RAW_PAYLOAD         VARIANT,
    INGESTED_AT         TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- Stream to capture new/changed rows
CREATE STREAM IF NOT EXISTS RAW_TRANSACTIONS_STREAM
    ON TABLE RAW_TRANSACTIONS
    APPEND_ONLY = TRUE;

-- Target enriched table
CREATE TABLE IF NOT EXISTS ENRICHED_TRANSACTIONS (
    TRANSACTION_ID      VARCHAR(36)     NOT NULL,
    ACCOUNT_ID          VARCHAR(20)     NOT NULL,
    CUSTOMER_NAME       VARCHAR(100),
    CUSTOMER_SEGMENT    VARCHAR(20),
    MERCHANT_ID         VARCHAR(20),
    MERCHANT_NAME       VARCHAR(100),
    MERCHANT_CATEGORY   VARCHAR(50),
    AMOUNT              NUMBER(18,2)    NOT NULL,
    AMOUNT_NZD          NUMBER(18,2),
    CURRENCY            VARCHAR(3),
    TRANSACTION_TYPE    VARCHAR(20),
    TRANSACTION_TS      TIMESTAMP_NTZ   NOT NULL,
    CHANNEL             VARCHAR(20),
    IS_INTERNATIONAL    BOOLEAN         DEFAULT FALSE,
    RISK_SCORE          NUMBER(5,2),
    ENRICHED_AT         TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

-- TODO: Task to process stream every minute
-- Needs to JOIN with DIM_CUSTOMER and DIM_MERCHANT
-- and calculate AMOUNT_NZD via FX_RATES table
CREATE OR REPLACE TASK ENRICH_TRANSACTIONS_TASK
    WAREHOUSE = BANKING_WH
    SCHEDULE = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW_TRANSACTIONS_STREAM')
AS
    -- TODO: implement enrichment logic
    SELECT 1;

ALTER TASK ENRICH_TRANSACTIONS_TASK RESUME;
