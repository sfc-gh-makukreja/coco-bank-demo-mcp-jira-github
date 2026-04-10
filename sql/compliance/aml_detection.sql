-- =============================================================
-- SLS-4: AML Suspicious Activity Detection View
-- Flags transactions matching NZ AML/CFT Act 2009 patterns:
--   - Large cash transactions (>NZD 10,000)
--   - Rapid succession transactions (structuring)
--   - Transactions to high-risk jurisdictions
--   - Unusual after-hours activity
-- =============================================================

USE DATABASE ANZ_BANKING;
USE SCHEMA COMPLIANCE;

CREATE OR REPLACE VIEW V_AML_SUSPICIOUS_ACTIVITY AS
WITH TRANSACTION_PATTERNS AS (
    SELECT
        ACCOUNT_ID,
        TRANSACTION_ID,
        AMOUNT_NZD,
        TRANSACTION_TS,
        CHANNEL,
        TRANSACTION_TYPE,
        IS_INTERNATIONAL,
        -- Large cash flag
        CASE WHEN AMOUNT_NZD >= 10000 AND TRANSACTION_TYPE = 'CASH'
             THEN TRUE ELSE FALSE END                        AS IS_LARGE_CASH,
        -- After hours flag (10pm - 6am NZST)
        CASE WHEN HOUR(CONVERT_TIMEZONE('Pacific/Auckland', TRANSACTION_TS))
                  NOT BETWEEN 6 AND 22
             THEN TRUE ELSE FALSE END                        AS IS_AFTER_HOURS,
        -- TODO: structuring detection
        -- (multiple txns just under $10k within 24hrs on same account)
        NULL::BOOLEAN                                        AS IS_STRUCTURING,
        -- TODO: high-risk jurisdiction flag
        -- (join REF_HIGH_RISK_COUNTRIES on MERCHANT_COUNTRY)
        NULL::BOOLEAN                                        AS IS_HIGH_RISK_JURISDICTION
    FROM ANZ_BANKING.PAYMENTS.ENRICHED_TRANSACTIONS
    WHERE TRANSACTION_TS >= DATEADD('day', -90, CURRENT_TIMESTAMP())
)
SELECT
    ACCOUNT_ID,
    TRANSACTION_ID,
    AMOUNT_NZD,
    TRANSACTION_TS,
    ARRAY_CONSTRUCT_COMPACT(
        IFF(IS_LARGE_CASH,             'LARGE_CASH', NULL),
        IFF(IS_AFTER_HOURS,            'AFTER_HOURS', NULL),
        IFF(IS_STRUCTURING,            'STRUCTURING', NULL),
        IFF(IS_HIGH_RISK_JURISDICTION, 'HIGH_RISK_JURISDICTION', NULL)
    )                                                        AS RISK_FLAGS,
    CURRENT_TIMESTAMP()                                      AS FLAGGED_AT
FROM TRANSACTION_PATTERNS
WHERE IS_LARGE_CASH OR IS_AFTER_HOURS
   OR IS_STRUCTURING OR IS_HIGH_RISK_JURISDICTION;
