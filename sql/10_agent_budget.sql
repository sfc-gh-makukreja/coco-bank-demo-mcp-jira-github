-- Mortgage Underwriting Assistant: Agent Resource Budget
-- Run as ACCOUNTADMIN
-- Monitors Cortex Agent credit usage with tag-based cost attribution.
-- - 100 credits/month limit
-- - Email notification at 50% threshold
-- - Revokes MORTGAGE_AGENT_USER access at 100%
-- - Auto-reinstates access at each budget cycle start

USE ROLE ACCOUNTADMIN;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;
USE WAREHOUSE MORTGAGE_WH;

-- ============================================================
-- 1. CREATE COST CENTER TAG
-- ============================================================
CREATE TAG IF NOT EXISTS AGENT_COST_CENTER
  ALLOWED_VALUES 'mortgage-agent'
  COMMENT = 'Cost center tag for mortgage underwriting agent budget tracking';

-- ============================================================
-- 2. APPLY TAG TO AGENT
-- ============================================================
ALTER AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.MORTGAGE_UNDERWRITING_ASSISTANT
  SET TAG MORTGAGE_DEMO_DB.MORTGAGE_DEMO.AGENT_COST_CENTER = 'mortgage-agent';

-- ============================================================
-- 3. CREATE CUSTOM BUDGET + SET SPENDING LIMIT
-- ============================================================
CREATE SNOWFLAKE.CORE.BUDGET MORTGAGE_AGENT_BUDGET();

CALL MORTGAGE_AGENT_BUDGET!SET_SPENDING_LIMIT(100);

-- ============================================================
-- 4. ASSOCIATE TAG WITH BUDGET
-- ============================================================
CALL MORTGAGE_AGENT_BUDGET!SET_RESOURCE_TAGS(
  [
    [(SELECT SYSTEM$REFERENCE('TAG',
       'MORTGAGE_DEMO_DB.MORTGAGE_DEMO.AGENT_COST_CENTER',
       'SESSION', 'applybudget')),
     'mortgage-agent']
  ],
  'UNION');

-- ============================================================
-- 5. EMAIL NOTIFICATION AT 50%
-- ============================================================
CALL MORTGAGE_AGENT_BUDGET!SET_EMAIL_NOTIFICATIONS(
  'ML_ALERTS',
  'manish.kukreja@snowflake.com');

CALL MORTGAGE_AGENT_BUDGET!SET_NOTIFICATION_THRESHOLD(50);

-- ============================================================
-- 6. REVOKE ACCESS STORED PROCEDURE + CUSTOM ACTION AT 100%
-- ============================================================
CREATE OR REPLACE PROCEDURE SP_REVOKE_AGENT_ACCESS()
RETURNS STRING
LANGUAGE SQL
AS
BEGIN
  REVOKE USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.MORTGAGE_UNDERWRITING_ASSISTANT
    FROM ROLE MORTGAGE_AGENT_USER;
  RETURN 'MORTGAGE_AGENT_USER access to agent revoked due to budget limit';
END;

-- Grant procedure to SNOWFLAKE application so budget can invoke it
GRANT USAGE ON DATABASE MORTGAGE_DEMO_DB TO APPLICATION SNOWFLAKE;
GRANT USAGE ON SCHEMA MORTGAGE_DEMO_DB.MORTGAGE_DEMO TO APPLICATION SNOWFLAKE;
GRANT USAGE ON PROCEDURE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.SP_REVOKE_AGENT_ACCESS()
  TO APPLICATION SNOWFLAKE;

-- Add custom action: revoke at 100% actual spend
CALL MORTGAGE_AGENT_BUDGET!ADD_CUSTOM_ACTION(
  SYSTEM$REFERENCE('PROCEDURE',
    'MORTGAGE_DEMO_DB.MORTGAGE_DEMO.SP_REVOKE_AGENT_ACCESS()'),
  ARRAY_CONSTRUCT(),
  'ACTUAL',
  100);

-- ============================================================
-- 7. REINSTATE ACCESS AT CYCLE START
-- ============================================================
CREATE OR REPLACE PROCEDURE SP_REINSTATE_AGENT_ACCESS()
RETURNS STRING
LANGUAGE SQL
AS
BEGIN
  GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.MORTGAGE_UNDERWRITING_ASSISTANT
    TO ROLE MORTGAGE_AGENT_USER;
  RETURN 'MORTGAGE_AGENT_USER access to agent reinstated for new budget cycle';
END;

GRANT USAGE ON PROCEDURE MORTGAGE_DEMO_DB.MORTGAGE_DEMO.SP_REINSTATE_AGENT_ACCESS()
  TO APPLICATION SNOWFLAKE;

CALL MORTGAGE_AGENT_BUDGET!SET_CYCLE_START_ACTION(
  SYSTEM$REFERENCE('PROCEDURE',
    'MORTGAGE_DEMO_DB.MORTGAGE_DEMO.SP_REINSTATE_AGENT_ACCESS()'),
  ARRAY_CONSTRUCT());
