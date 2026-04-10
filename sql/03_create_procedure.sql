-- Mortgage Underwriting Assistant: Custom Action Tool
-- Stored procedure for agent to flag applications violating policy
-- Run as MORTGAGE_AGENT_ADMIN role

USE ROLE MORTGAGE_AGENT_ADMIN;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;
USE WAREHOUSE MORTGAGE_WH;

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
    # Validate the application_id exists
    check = session.sql(
        "SELECT COUNT(*) AS CNT FROM MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS WHERE APPLICATION_ID = ?",
        params=[application_id]
    ).collect()

    if check[0]['CNT'] == 0:
        return f"Error: Application {application_id} not found in LOAN_APPLICATIONS."

    # Update the application status to Exception Review
    session.sql(
        "UPDATE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS SET STATUS = 'Exception Review' WHERE APPLICATION_ID = ?",
        params=[application_id]
    ).collect()

    # Insert audit log entry
    session.sql(
        "INSERT INTO MORTGAGE_DEMO_DB.MORTGAGE_DEMO.EXCEPTION_LOGS (LOG_ID, APPLICATION_ID, FLAG_REASON, TIMESTAMP) "
        "SELECT UUID_STRING(), ?, ?, CURRENT_TIMESTAMP() FROM TABLE(GENERATOR(ROWCOUNT => 1))",
        params=[application_id, reason]
    ).collect()

    return f"Application {application_id} successfully flagged for exception review. Reason: {reason}"
$$;
