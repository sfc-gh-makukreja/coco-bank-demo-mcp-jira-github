-- =============================================================
-- SLS-4: Lending Compliance — Regulatory Breach Detection View
-- Flags loan applications that breach APRA/RBNZ lending thresholds:
--   - LTV ratio exceeds 80% (investment) or 90% (owner-occupier)
--   - DTI ratio exceeds 40%
--   - Credit score below minimum (620 PAYG / 680 Self-Employed)
--   - Loan amount exceeds income multiple (6x annual income)
-- =============================================================

USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;

CREATE OR REPLACE VIEW V_LENDING_COMPLIANCE_BREACHES AS
WITH APPLICATION_METRICS AS (
    SELECT
        la.APPLICATION_ID,
        la.APPLICANT_ID,
        ap.FULL_NAME,
        la.LOAN_AMOUNT,
        la.PROPERTY_VALUE,
        la.LOAN_PURPOSE,
        la.STATUS,
        ap.CREDIT_SCORE,
        ap.EMPLOYMENT_TYPE,
        ap.ANNUAL_INCOME,
        ap.MONTHLY_DEBT_OBLIGATIONS,
        -- Calculate key ratios
        ROUND(la.LOAN_AMOUNT / NULLIF(la.PROPERTY_VALUE, 0) * 100, 2) AS LTV_RATIO,
        ROUND((ap.MONTHLY_DEBT_OBLIGATIONS * 12) / NULLIF(ap.ANNUAL_INCOME, 0) * 100, 2) AS DTI_RATIO,
        -- LTV breach flag
        CASE
            WHEN la.LOAN_PURPOSE = 'Investment'
                 AND ROUND(la.LOAN_AMOUNT / NULLIF(la.PROPERTY_VALUE, 0) * 100, 2) > 80
                THEN TRUE
            WHEN la.LOAN_PURPOSE = 'Owner-Occupier'
                 AND ROUND(la.LOAN_AMOUNT / NULLIF(la.PROPERTY_VALUE, 0) * 100, 2) > 90
                THEN TRUE
            ELSE FALSE
        END AS IS_LTV_BREACH,
        -- DTI breach flag
        CASE
            WHEN ROUND((ap.MONTHLY_DEBT_OBLIGATIONS * 12) / NULLIF(ap.ANNUAL_INCOME, 0) * 100, 2) > 40
                THEN TRUE
            ELSE FALSE
        END AS IS_DTI_BREACH,
        -- TODO: Credit score breach flag
        -- PAYG minimum: 620, Self-Employed minimum: 680
        NULL::BOOLEAN AS IS_CREDIT_BREACH,
        -- TODO: Income multiple breach flag
        -- Loan amount should not exceed 6x annual income
        NULL::BOOLEAN AS IS_INCOME_MULTIPLE_BREACH
    FROM MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS la
    JOIN MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES ap
        ON la.APPLICANT_ID = ap.APPLICANT_ID
    WHERE la.STATUS IN ('Pending', 'Approved')
)
SELECT
    APPLICATION_ID,
    APPLICANT_ID,
    FULL_NAME,
    LOAN_AMOUNT,
    PROPERTY_VALUE,
    LOAN_PURPOSE,
    STATUS,
    LTV_RATIO,
    DTI_RATIO,
    CREDIT_SCORE,
    EMPLOYMENT_TYPE,
    ARRAY_CONSTRUCT_COMPACT(
        IFF(IS_LTV_BREACH,              'LTV_BREACH', NULL),
        IFF(IS_DTI_BREACH,              'DTI_BREACH', NULL),
        IFF(IS_CREDIT_BREACH,           'CREDIT_SCORE_BREACH', NULL),
        IFF(IS_INCOME_MULTIPLE_BREACH,  'INCOME_MULTIPLE_BREACH', NULL)
    ) AS BREACH_FLAGS,
    CURRENT_TIMESTAMP() AS FLAGGED_AT
FROM APPLICATION_METRICS
WHERE IS_LTV_BREACH OR IS_DTI_BREACH
   OR IS_CREDIT_BREACH OR IS_INCOME_MULTIPLE_BREACH;
