-- =============================================================
-- SLS-6: Data Quality Tests — Mortgage Ingestion Layer
-- Using Snowflake Data Metric Functions (DMFs)
-- =============================================================

USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;

-- DMF: Null check on APPLICATION_ID
CREATE OR REPLACE DATA METRIC FUNCTION DMF_NULL_APPLICATION_ID(
    ARG_T TABLE(APPLICATION_ID VARCHAR)
) RETURNS NUMBER AS
'SELECT COUNT_IF(APPLICATION_ID IS NULL) FROM ARG_T';

ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS
    ADD DATA METRIC FUNCTION DMF_NULL_APPLICATION_ID
    ON (APPLICATION_ID);

-- TODO: Implement remaining DMFs:
--
-- DMF_DUPLICATE_APPLICATION_ID   — COUNT where APPLICATION_ID appears > 1 time
-- DMF_INVALID_CREDIT_SCORE       — COUNT_IF(CREDIT_SCORE < 300 OR CREDIT_SCORE > 850)
-- DMF_NEGATIVE_LOAN_AMOUNT       — COUNT_IF(LOAN_AMOUNT <= 0)
-- DMF_LTV_OUT_OF_RANGE           — COUNT_IF(LOAN_AMOUNT / PROPERTY_VALUE * 100 > 100)
--                                   (LTV > 100% means loan exceeds property value)
-- DMF_INVALID_STATUS             — COUNT_IF(STATUS NOT IN ('Pending','Approved','Declined','Exception Review'))
-- DMF_ORPHAN_APPLICANT           — COUNT of LOAN_APPLICATIONS where APPLICANT_ID
--                                   has no match in APPLICANT_PROFILES
-- DMF_INVALID_EMPLOYMENT_TYPE    — COUNT_IF(EMPLOYMENT_TYPE NOT IN ('PAYG','Self-Employed'))
