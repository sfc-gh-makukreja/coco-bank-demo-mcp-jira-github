-- Mortgage Underwriting Assistant: Data Policies (Masking + Row Access)
-- Run as ACCOUNTADMIN (needs privileges to create and apply policies)

USE ROLE ACCOUNTADMIN;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;
USE WAREHOUSE MORTGAGE_WH;

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

ALTER TABLE APPLICANT_PROFILES
  MODIFY COLUMN FULL_NAME
  SET MASKING POLICY MASK_FULL_NAME;

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

ALTER TABLE APPLICANT_PROFILES
  MODIFY COLUMN ANNUAL_INCOME
  SET MASKING POLICY MASK_ANNUAL_INCOME;

-- ============================================================
-- 3. ROW ACCESS POLICY: LOAN_APPLICATIONS
--    ADMIN sees all rows.
--    USER sees only Pending/Approved + Owner-Occupier rows.
-- ============================================================
CREATE OR REPLACE ROW ACCESS POLICY RAP_LOAN_APPLICATIONS
  AS (status_val VARCHAR, purpose_val VARCHAR) RETURNS BOOLEAN ->
  CURRENT_ROLE() IN ('MORTGAGE_AGENT_ADMIN', 'ACCOUNTADMIN')
  OR (status_val IN ('Pending', 'Approved') AND purpose_val = 'Owner-Occupier');

ALTER TABLE LOAN_APPLICATIONS
  ADD ROW ACCESS POLICY RAP_LOAN_APPLICATIONS
  ON (STATUS, LOAN_PURPOSE);
