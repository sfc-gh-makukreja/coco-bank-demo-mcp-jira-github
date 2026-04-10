-- =============================================================
-- SLS-5: Portfolio Risk Report
-- Currently runs in ~45s — needs optimisation
-- Issues identified:
--   1. Correlated subqueries causing repeated full table scans
--   2. No use of semantic view for pre-computed metrics
--   3. Redundant joins and repeated ratio calculations
-- TODO: Rewrite using CTEs or leverage the semantic view
-- =============================================================

USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;

-- SLOW VERSION (current) — do not use in production
-- This query calculates portfolio risk metrics but uses
-- correlated subqueries that cause N+1 scan patterns.

SELECT
    ap.EMPLOYMENT_TYPE,
    la.LOAN_PURPOSE,
    COUNT(DISTINCT la.APPLICATION_ID)                       AS TOTAL_APPLICATIONS,
    SUM(la.LOAN_AMOUNT)                                     AS TOTAL_EXPOSURE,
    AVG(ROUND(la.LOAN_AMOUNT / NULLIF(la.PROPERTY_VALUE, 0) * 100, 2))
                                                            AS AVG_LTV_RATIO,
    SUM(CASE WHEN la.STATUS = 'Declined'
             THEN la.LOAN_AMOUNT ELSE 0 END)                AS DECLINED_EXPOSURE,
    SUM(CASE WHEN la.STATUS = 'Declined'
             THEN la.LOAN_AMOUNT ELSE 0 END)
        / NULLIF(SUM(la.LOAN_AMOUNT), 0) * 100              AS DECLINE_RATIO_PCT,
    -- Correlated subquery #1 — causes full scan per employment type
    (SELECT AVG(CREDIT_SCORE)
     FROM MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES
     WHERE EMPLOYMENT_TYPE = ap.EMPLOYMENT_TYPE)            AS AVG_CREDIT_SCORE,
    -- Inefficient: counting exceptions per group via subquery in HAVING-style
    SUM(exc.EXCEPTION_COUNT)                                AS TOTAL_EXCEPTIONS
FROM MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS la
JOIN MORTGAGE_DEMO_DB.MORTGAGE_DEMO.APPLICANT_PROFILES ap
    ON la.APPLICANT_ID = ap.APPLICANT_ID
LEFT JOIN (
    SELECT APPLICATION_ID, COUNT(*) AS EXCEPTION_COUNT
    FROM MORTGAGE_DEMO_DB.MORTGAGE_DEMO.EXCEPTION_LOGS
    GROUP BY APPLICATION_ID
) exc ON exc.APPLICATION_ID = la.APPLICATION_ID
WHERE la.STATUS IN ('Pending', 'Approved', 'Declined', 'Exception Review')
GROUP BY 1, 2
ORDER BY DECLINE_RATIO_PCT DESC;

-- TODO: Rewrite this query using CTEs to eliminate correlated subqueries:
--   1. Pre-aggregate credit scores by EMPLOYMENT_TYPE in a CTE
--   2. Pre-aggregate exception counts by APPLICATION_ID in a CTE
--   3. Join CTEs to the main query instead of using subqueries
--   4. Consider using the MORTGAGE_SEMANTIC_VIEW for pre-computed LTV/DTI ratios
