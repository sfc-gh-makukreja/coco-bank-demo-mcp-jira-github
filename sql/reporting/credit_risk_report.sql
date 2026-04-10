-- =============================================================
-- SLS-5: Credit Risk Portfolio Report
-- Currently runs in ~45s — needs optimisation
-- Issues identified:
--   1. Correlated subqueries causing repeated full table scans
--   2. No clustering on FACT_LOANS
--   3. Missing partition pruning on TRANSACTION_TS
-- TODO: Rewrite using CTEs + clustering recommendations
-- =============================================================

USE DATABASE ANZ_BANKING;
USE SCHEMA REPORTING;

-- SLOW VERSION (current) — do not use in production
SELECT
    c.CUSTOMER_SEGMENT,
    c.REGION,
    p.PRODUCT_TYPE,
    COUNT(DISTINCT l.LOAN_ID)                               AS TOTAL_LOANS,
    SUM(l.OUTSTANDING_BALANCE)                              AS TOTAL_EXPOSURE,
    AVG(l.LVR)                                              AS AVG_LVR,
    SUM(CASE WHEN l.DAYS_PAST_DUE > 90
             THEN l.OUTSTANDING_BALANCE ELSE 0 END)         AS NPL_EXPOSURE,
    SUM(CASE WHEN l.DAYS_PAST_DUE > 90
             THEN l.OUTSTANDING_BALANCE ELSE 0 END)
        / NULLIF(SUM(l.OUTSTANDING_BALANCE), 0) * 100       AS NPL_RATIO_PCT,
    -- Correlated subquery #1 — causes full scan per segment
    (SELECT AVG(CREDIT_SCORE)
     FROM ANZ_BANKING.CUSTOMERS.DIM_CUSTOMER
     WHERE CUSTOMER_SEGMENT = c.CUSTOMER_SEGMENT)           AS AVG_CREDIT_SCORE,
    -- Correlated subquery #2 — causes full scan per loan
    (SELECT COUNT(*)
     FROM ANZ_BANKING.PAYMENTS.ENRICHED_TRANSACTIONS t
     WHERE t.ACCOUNT_ID = l.ACCOUNT_ID
     AND t.TRANSACTION_TS >= DATEADD('month', -3, CURRENT_DATE())) AS TXN_COUNT_90D
FROM ANZ_BANKING.LENDING.FACT_LOANS l
JOIN ANZ_BANKING.CUSTOMERS.DIM_CUSTOMER c   ON l.CUSTOMER_ID = c.CUSTOMER_ID
JOIN ANZ_BANKING.LENDING.DIM_PRODUCT p      ON l.PRODUCT_ID  = p.PRODUCT_ID
WHERE l.LOAN_STATUS = 'ACTIVE'
GROUP BY 1, 2, 3
ORDER BY NPL_RATIO_PCT DESC;
