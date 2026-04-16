-- =============================================================
-- SLS-3: Dynamic Data Masking — Applicant PII Fields
-- APRA CPS 234 & RBNZ BS11 compliance
-- Masks PII for non-privileged roles
-- =============================================================

USE ROLE MORTGAGE_AGENT_ADMIN;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;
USE WAREHOUSE MORTGAGE_WH;

-- Roles:
-- MORTGAGE_AGENT_USER  : sees masked data
-- MORTGAGE_AGENT_ADMIN : sees full data
-- ACCOUNTADMIN         : sees full data

-- ============================================================
-- 1. MASKING POLICY: FULL_NAME (VARCHAR -> VARCHAR)
--    ADMIN sees real names; USER sees '***MASKED***'
-- ============================================================
CREATE OR REPLACE MASKING POLICY MASK_FULL_NAME
    AS (val VARCHAR) RETURNS VARCHAR ->
        CASE
            WHEN CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN') THEN val
            ELSE '***MASKED***'
        END;

-- ============================================================
-- 2. MASKING POLICY: ANNUAL_INCOME (NUMBER -> NUMBER)
--    ADMIN sees real income; USER sees NULL
-- ============================================================
CREATE OR REPLACE MASKING POLICY MASK_ANNUAL_INCOME
    AS (val NUMBER(12,2)) RETURNS NUMBER(12,2) ->
        CASE
            WHEN CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN') THEN val
            ELSE NULL
        END;

-- ============================================================
-- 3. MASKING POLICY: CREDIT_SCORE (NUMBER -> NUMBER)
--    ADMIN sees exact score; USER sees band midpoint:
--      300-579 (Poor)        -> 450
--      580-669 (Fair)        -> 625
--      670-739 (Good)        -> 700
--      740-799 (Very Good)   -> 770
--      800-850 (Exceptional) -> 825
-- ============================================================
CREATE OR REPLACE MASKING POLICY MASK_CREDIT_SCORE
    AS (val NUMBER(4,0)) RETURNS NUMBER(4,0) ->
        CASE
            WHEN CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN') THEN val
            WHEN val BETWEEN 800 AND 850 THEN 825
            WHEN val BETWEEN 740 AND 799 THEN 770
            WHEN val BETWEEN 670 AND 739 THEN 700
            WHEN val BETWEEN 580 AND 669 THEN 625
            ELSE 450
        END;

-- ============================================================
-- 4. MASKING POLICY: MONTHLY_DEBT_OBLIGATIONS (NUMBER -> NUMBER)
--    ADMIN sees real debt; USER sees NULL
-- ============================================================
CREATE OR REPLACE MASKING POLICY MASK_MONTHLY_DEBT
    AS (val NUMBER(10,2)) RETURNS NUMBER(10,2) ->
        CASE
            WHEN CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN') THEN val
            ELSE NULL
        END;

-- ============================================================
-- 5. EMPLOYMENT_TYPE — No masking policy applied
--    Employment type (PAYG / Self-Employed) is a categorical
--    classification, not Personally Identifiable Information
--    under APRA CPS 234. It cannot identify an individual on
--    its own or in combination with other non-PII fields.
-- ============================================================

-- ============================================================
-- 6. ROW ACCESS POLICY: LOAN_APPLICATIONS
--    ADMIN sees all rows.
--    USER sees only Pending/Approved + Owner-Occupier rows.
-- ============================================================
CREATE OR REPLACE ROW ACCESS POLICY RAP_LOAN_APPLICATIONS
    AS (status_val VARCHAR, purpose_val VARCHAR) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN')
        OR (status_val IN ('Pending', 'Approved') AND purpose_val = 'Owner-Occupier');

-- ============================================================
-- Apply masking policies to APPLICANT_PROFILES
-- ============================================================
ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
    MODIFY COLUMN FULL_NAME
    SET MASKING POLICY MASK_FULL_NAME;

ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
    MODIFY COLUMN ANNUAL_INCOME
    SET MASKING POLICY MASK_ANNUAL_INCOME;

ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
    MODIFY COLUMN CREDIT_SCORE
    SET MASKING POLICY MASK_CREDIT_SCORE;

ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
    MODIFY COLUMN MONTHLY_DEBT_OBLIGATIONS
    SET MASKING POLICY MASK_MONTHLY_DEBT;

-- ============================================================
-- Apply row access policy to LOAN_APPLICATIONS
-- ============================================================
ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS
    ADD ROW ACCESS POLICY RAP_LOAN_APPLICATIONS
    ON (STATUS, LOAN_PURPOSE);
