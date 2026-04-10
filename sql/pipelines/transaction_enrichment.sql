-- =============================================================
-- SLS-2: Automated Loan Policy Violation Detection
-- Creates a stored procedure for the Cortex Agent to flag
-- applications that violate lending policy, plus a Task
-- to auto-detect LTV violations on new applications.
-- Status: IN PROGRESS — auto-detection task TODO
-- =============================================================

USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;

-- Exception logs table (audit trail for agent actions)
CREATE TABLE IF NOT EXISTS EXCEPTION_LOGS (
    LOG_ID              VARCHAR(36)   PRIMARY KEY,
    APPLICATION_ID      VARCHAR(20)   NOT NULL,
    FLAG_REASON         VARCHAR(2000) NOT NULL,
    TIMESTAMP           TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP()
);

-- Stored procedure: Agent action tool to flag an application
CREATE OR REPLACE PROCEDURE FLAG_APPLICATION_EXCEPTION(application_id VARCHAR, reason VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS CALLER
AS
$$
def main(session, application_id: str, reason: str) -> str:
    check = session.sql(
        "SELECT COUNT(*) AS CNT FROM MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS WHERE APPLICATION_ID = ?",
        params=[application_id]
    ).collect()

    if check[0]['CNT'] == 0:
        return f"Error: Application {application_id} not found in LOAN_APPLICATIONS."

    session.sql(
        "UPDATE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS SET STATUS = 'Exception Review' WHERE APPLICATION_ID = ?",
        params=[application_id]
    ).collect()

    session.sql(
        "INSERT INTO MORTGAGE_DEMO_DB.MORTGAGE_DEMO.EXCEPTION_LOGS (LOG_ID, APPLICATION_ID, FLAG_REASON, TIMESTAMP) "
        "SELECT UUID_STRING(), ?, ?, CURRENT_TIMESTAMP() FROM TABLE(GENERATOR(ROWCOUNT => 1))",
        params=[application_id, reason]
    ).collect()

    return f"Application {application_id} successfully flagged for exception review. Reason: {reason}"
$$;

-- TODO: Create a Task that runs every 5 minutes to auto-detect policy violations:
--   - Check all Pending applications where LTV_RATIO > 90%
--     (LOAN_AMOUNT / PROPERTY_VALUE * 100 > 90)
--   - For each violation, call FLAG_APPLICATION_EXCEPTION with reason
--   - Use a Stream on LOAN_APPLICATIONS to only process new/changed rows
--   - Schedule: USING CRON */5 * * * * Pacific/Auckland
