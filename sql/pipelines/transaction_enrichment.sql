-- =============================================================
-- SLS-2: Automated Loan Policy Violation Detection
-- Creates a Stream on LOAN_APPLICATIONS plus a scheduled Task
-- to auto-detect LTV violations and flag them via
-- FLAG_APPLICATION_EXCEPTION.
-- =============================================================

USE ROLE MORTGAGE_AGENT_ADMIN;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;
USE WAREHOUSE MORTGAGE_WH;

-- Stream to capture new rows in LOAN_APPLICATIONS
CREATE OR REPLACE STREAM LOAN_APPLICATIONS_STREAM
    ON TABLE LOAN_APPLICATIONS
    APPEND_ONLY = TRUE;

-- Procedure to iterate stream violations and flag each one
CREATE OR REPLACE PROCEDURE DETECT_LTV_VIOLATIONS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
BEGIN
    LET violations_cursor CURSOR FOR
        SELECT APPLICATION_ID,
               ROUND(LOAN_AMOUNT / NULLIF(PROPERTY_VALUE, 0) * 100, 2) AS LTV_RATIO
        FROM LOAN_APPLICATIONS_STREAM
        WHERE STATUS = 'Pending'
          AND PROPERTY_VALUE > 0
          AND ROUND(LOAN_AMOUNT / NULLIF(PROPERTY_VALUE, 0) * 100, 2) > 90;

    LET flagged_count INTEGER := 0;
    LET app_id VARCHAR;
    LET ltv_val NUMBER(10,2);
    LET flag_reason VARCHAR;

    FOR rec IN violations_cursor DO
        app_id := rec.APPLICATION_ID;
        ltv_val := rec.LTV_RATIO;
        flag_reason := 'Auto-detected LTV violation: LTV ratio ' || :ltv_val || '% exceeds 90% policy limit';
        CALL FLAG_APPLICATION_EXCEPTION(:app_id, :flag_reason);
        flagged_count := flagged_count + 1;
    END FOR;

    RETURN 'LTV violation scan complete. Flagged ' || :flagged_count || ' application(s).';
END;

-- Scheduled task: runs every 5 minutes when stream has data
CREATE OR REPLACE TASK DETECT_LTV_VIOLATIONS_TASK
    WAREHOUSE = MORTGAGE_WH
    SCHEDULE  = 'USING CRON */5 * * * * Pacific/Auckland'
    WHEN SYSTEM$STREAM_HAS_DATA('MORTGAGE_DEMO_DB.MORTGAGE_DEMO.LOAN_APPLICATIONS_STREAM')
AS
    CALL DETECT_LTV_VIOLATIONS();

-- Enable the task (tasks are created in suspended state)
ALTER TASK DETECT_LTV_VIOLATIONS_TASK RESUME;
