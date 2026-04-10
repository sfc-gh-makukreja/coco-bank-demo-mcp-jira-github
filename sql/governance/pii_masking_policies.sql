-- =============================================================
-- SLS-3: Dynamic Data Masking — Customer PII Fields
-- APRA CPS 234 & RBNZ BS11 compliance
-- Masks PII for non-privileged roles
-- =============================================================

USE DATABASE ANZ_BANKING;
USE SCHEMA GOVERNANCE;

-- Roles:
-- BANKING_ANALYST    : sees masked data
-- BANKING_COMPLIANCE : sees full data
-- BANKING_ADMIN      : sees full data

-- Full name masking
CREATE OR REPLACE MASKING POLICY MASK_CUSTOMER_NAME
    AS (val STRING) RETURNS STRING ->
        CASE
            WHEN CURRENT_ROLE() IN ('BANKING_COMPLIANCE', 'BANKING_ADMIN', 'SYSADMIN') THEN val
            ELSE '***MASKED***'
        END;

-- TODO: Add masking policies for:
--   MASK_EMAIL     — show domain only (e.g. j***@anz.co.nz)
--   MASK_PHONE     — show last 4 digits only
--   MASK_IRD       — full mask for IRD/tax identifiers
--   MASK_DOB       — show year only
--   MASK_ADDRESS   — show suburb/city only

-- Apply policy to DIM_CUSTOMER
ALTER TABLE ANZ_BANKING.CUSTOMERS.DIM_CUSTOMER
    MODIFY COLUMN FULL_NAME
    SET MASKING POLICY GOVERNANCE.MASK_CUSTOMER_NAME;
