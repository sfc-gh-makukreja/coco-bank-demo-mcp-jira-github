-- =============================================================
-- SLS-6: Data Quality Tests — Core Banking Ingestion Layer
-- Using Snowflake Data Metric Functions (DMFs)
-- =============================================================

USE DATABASE ANZ_BANKING;
USE SCHEMA QUALITY;

-- DMF: Null check on TRANSACTION_ID
CREATE OR REPLACE DATA METRIC FUNCTION DMF_NULL_TRANSACTION_ID(
    ARG_T TABLE(TRANSACTION_ID VARCHAR)
) RETURNS NUMBER AS
'SELECT COUNT_IF(TRANSACTION_ID IS NULL) FROM ARG_T';

ALTER TABLE ANZ_BANKING.PAYMENTS.RAW_TRANSACTIONS
    ADD DATA METRIC FUNCTION QUALITY.DMF_NULL_TRANSACTION_ID
    ON (TRANSACTION_ID)
    TRIGGER_SCHEDULE = 'USING CRON 0 6 * * * Pacific/Auckland';

-- TODO: Implement remaining DMFs:
--
-- DMF_DUPLICATE_TRANSACTION_ID  — COUNT where ID appears > 1 time
-- DMF_NEGATIVE_AMOUNT           — COUNT_IF(AMOUNT <= 0)
-- DMF_INVALID_STATUS            — COUNT_IF(STATUS NOT IN ('PENDING','CLEARED','FAILED','REVERSED'))
-- DMF_FUTURE_TIMESTAMP          — COUNT_IF(TRANSACTION_TS > CURRENT_TIMESTAMP())
-- DMF_ENRICHMENT_LAG            — COUNT of RAW txns with no ENRICHED match after 5 mins
-- DMF_INVALID_EMAIL             — COUNT_IF(EMAIL not matching regex)
-- DMF_INVALID_NZ_PHONE          — COUNT_IF(PHONE not matching +64 or 0X format)
