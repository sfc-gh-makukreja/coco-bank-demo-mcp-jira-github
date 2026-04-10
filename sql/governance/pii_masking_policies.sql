-- =============================================================
-- SLS-3: Dynamic Data Masking — Applicant PII Fields
-- APRA CPS 234 & RBNZ BS11 compliance
-- Masks PII for non-privileged roles
-- =============================================================

USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;

-- Roles:
-- MORTGAGE_AGENT_USER  : sees masked data
-- MORTGAGE_AGENT_ADMIN : sees full data
-- ACCOUNTADMIN         : sees full data

-- Full name masking (already deployed)
CREATE OR REPLACE MASKING POLICY MASK_FULL_NAME
    AS (val VARCHAR) RETURNS VARCHAR ->
        CASE
            WHEN CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN') THEN val
            ELSE '***MASKED***'
        END;

-- Annual income masking (already deployed)
CREATE OR REPLACE MASKING POLICY MASK_ANNUAL_INCOME
    AS (val NUMBER(12,2)) RETURNS NUMBER(12,2) ->
        CASE
            WHEN CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN') THEN val
            ELSE NULL
        END;

-- TODO: Add masking policies for:
--   MASK_CREDIT_SCORE          — show band only (e.g. 'Good 700-749') for USER role
--   MASK_MONTHLY_DEBT          — full mask (NULL) for USER role
--   MASK_EMPLOYMENT_TYPE       — no mask needed (not PII), but add comment explaining why

-- TODO: Add row access policy on LOAN_APPLICATIONS:
--   MORTGAGE_AGENT_ADMIN sees all rows
--   MORTGAGE_AGENT_USER sees only Pending + Approved rows for Owner-Occupier purpose

-- Apply existing policies to APPLICANT_PROFILES
ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
    MODIFY COLUMN FULL_NAME
    SET MASKING POLICY MASK_FULL_NAME;

ALTER TABLE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
    MODIFY COLUMN ANNUAL_INCOME
    SET MASKING POLICY MASK_ANNUAL_INCOME;
