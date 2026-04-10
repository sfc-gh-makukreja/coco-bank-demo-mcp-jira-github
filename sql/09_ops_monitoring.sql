-- Mortgage Underwriting Assistant: Ops Monitoring
-- Sets up monitoring schema, views, alerts, health check task, and baseline
-- Run as ACCOUNTADMIN

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE MORTGAGE_WH;

-- ============================================================================
-- 1. CREATE OPS MONITORING ROLE
-- ============================================================================
CREATE ROLE IF NOT EXISTS MORTGAGE_OPS_MONITOR
  COMMENT = 'Ops monitoring role for Mortgage Underwriting Assistant';

GRANT ROLE MORTGAGE_OPS_MONITOR TO ROLE ACCOUNTADMIN;
GRANT EXECUTE MANAGED ALERT ON ACCOUNT TO ROLE MORTGAGE_OPS_MONITOR;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE MORTGAGE_OPS_MONITOR;
GRANT USAGE ON WAREHOUSE MORTGAGE_WH TO ROLE MORTGAGE_OPS_MONITOR;

-- ============================================================================
-- 2. CREATE OPS_MONITORING SCHEMA
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS MORTGAGE_DEMO_DB.OPS_MONITORING
  COMMENT = 'Monitoring views, alerts, and baselines for the Mortgage Underwriting Assistant agent';

GRANT USAGE ON DATABASE MORTGAGE_DEMO_DB TO ROLE MORTGAGE_OPS_MONITOR;
GRANT USAGE ON SCHEMA MORTGAGE_DEMO_DB.OPS_MONITORING TO ROLE MORTGAGE_OPS_MONITOR;
GRANT CREATE TABLE ON SCHEMA MORTGAGE_DEMO_DB.OPS_MONITORING TO ROLE MORTGAGE_OPS_MONITOR;
GRANT CREATE VIEW ON SCHEMA MORTGAGE_DEMO_DB.OPS_MONITORING TO ROLE MORTGAGE_OPS_MONITOR;

USE SCHEMA MORTGAGE_DEMO_DB.OPS_MONITORING;

-- ============================================================================
-- 3. QUANTITATIVE MONITORING VIEWS
-- ============================================================================

-- 3a. Agent Latency View
CREATE OR REPLACE VIEW V_AGENT_LATENCY AS
SELECT
    TIMESTAMP AS EVENT_TS,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.request_id"::VARCHAR AS REQUEST_ID,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER AS DURATION_MS,
    ROUND(RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER / 1000, 2) AS DURATION_SEC,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.status"::VARCHAR AS STATUS,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.code"::VARCHAR AS STATUS_CODE,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.description"::VARCHAR AS STATUS_DESC,
    LEFT(RECORD_ATTRIBUTES:"snow.ai.observability.agent.messages"::VARCHAR, 200) AS USER_MESSAGE_PREVIEW,
    RESOURCE_ATTRIBUTES:"snow.user.name"::VARCHAR AS USER_NAME
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
  AND RECORD:"name"::VARCHAR = 'AgentV2RequestResponseInfo';

-- 3b. Agent Errors View
CREATE OR REPLACE VIEW V_AGENT_ERRORS AS
SELECT
    TIMESTAMP AS EVENT_TS,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.request_id"::VARCHAR AS REQUEST_ID,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.name"::VARCHAR AS TOOL_NAME,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.status"::VARCHAR AS TOOL_STATUS,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.status.code"::VARCHAR AS TOOL_STATUS_CODE,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.status.description"::VARCHAR AS ERROR_DETAIL,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.sql_execution.query"::VARCHAR AS SQL_QUERY,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.sql_execution.status.description"::VARCHAR AS SQL_ERROR_DETAIL,
    RESOURCE_ATTRIBUTES:"snow.user.name"::VARCHAR AS USER_NAME
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
  AND (
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.status"::VARCHAR = 'ERROR'
    OR RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.sql_execution.status"::VARCHAR = 'ERROR'
    OR RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.description"::VARCHAR = 'ERROR'
  );

-- 3c. Agent Cost View
CREATE OR REPLACE VIEW V_AGENT_COST AS
SELECT
    USAGE_DATE,
    WAREHOUSE_NAME,
    CREDITS_USED,
    CREDITS_USED_COMPUTE,
    CREDITS_USED_CLOUD_SERVICES
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE WAREHOUSE_NAME = 'MORTGAGE_WH'
ORDER BY USAGE_DATE DESC, START_TIME DESC;

-- 3d. Agent Tool Usage View
CREATE OR REPLACE VIEW V_AGENT_TOOL_USAGE AS
SELECT
    DATE_TRUNC('day', TIMESTAMP) AS EVENT_DATE,
    RECORD:"name"::VARCHAR AS SPAN_NAME,
    COUNT(*) AS CALL_COUNT
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
  AND RECORD:"name"::VARCHAR LIKE 'ToolCall-%'
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- ============================================================================
-- 4. QUALITATIVE MONITORING VIEW
-- ============================================================================
CREATE OR REPLACE VIEW V_AGENT_QUALITY AS
SELECT
    TIMESTAMP AS EVENT_TS,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.request_id"::VARCHAR AS REQUEST_ID,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.status"::VARCHAR AS STATUS,
    RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.description"::VARCHAR AS STATUS_DESC,
    LEFT(RECORD_ATTRIBUTES:"snow.ai.observability.agent.messages"::VARCHAR, 200) AS USER_MESSAGE_PREVIEW,
    LEFT(RECORD_ATTRIBUTES:"snow.ai.observability.agent.response"::VARCHAR, 500) AS RESPONSE_PREVIEW
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
  AND RECORD:"name"::VARCHAR = 'AgentV2RequestResponseInfo'
  AND RECORD_ATTRIBUTES:"snow.ai.observability.span_type"::VARCHAR = 'record_root';

-- ============================================================================
-- 5. BASELINE METRICS TABLE
-- ============================================================================
CREATE OR REPLACE TABLE BASELINE_METRICS AS
WITH latency_stats AS (
    SELECT
        COUNT(*) AS total_requests,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER), 0) AS p50_ms,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER), 0) AS p95_ms,
        ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER), 0) AS p99_ms,
        ROUND(AVG(RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER), 0) AS avg_ms
    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
      AND RECORD:"name"::VARCHAR = 'AgentV2RequestResponseInfo'
),
error_stats AS (
    SELECT COUNT(*) AS error_count
    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
      AND (
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.status"::VARCHAR = 'ERROR'
        OR RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.description"::VARCHAR = 'ERROR'
      )
),
cost_stats AS (
    SELECT ROUND(AVG(CREDITS_USED), 6) AS avg_daily_credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE WAREHOUSE_NAME = 'MORTGAGE_WH'
      AND START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
)
SELECT
    CURRENT_TIMESTAMP() AS BASELINE_CAPTURED_AT,
    'MORTGAGE_UNDERWRITING_ASSISTANT' AS AGENT_NAME,
    l.total_requests,
    l.p50_ms AS LATENCY_P50_MS,
    l.p95_ms AS LATENCY_P95_MS,
    l.p99_ms AS LATENCY_P99_MS,
    l.avg_ms AS LATENCY_AVG_MS,
    e.error_count,
    ROUND(e.error_count / NULLIF(l.total_requests, 0) * 100, 2) AS ERROR_RATE_PCT,
    c.avg_daily_credits AS AVG_DAILY_CREDITS_MORTGAGE_WH
FROM latency_stats l, error_stats e, cost_stats c;

-- ============================================================================
-- 6. HEALTH CHECK LOG TABLE
-- ============================================================================
CREATE OR REPLACE TABLE HEALTH_CHECK_LOG (
    CHECK_TS            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REQUESTS_LAST_HOUR  NUMBER,
    ERRORS_LAST_HOUR    NUMBER,
    P50_MS_LAST_HOUR    NUMBER,
    P95_MS_LAST_HOUR    NUMBER,
    ERROR_RATE_PCT      NUMBER(5,2)
);

-- ============================================================================
-- 7. NOTIFICATION INTEGRATION
-- ============================================================================
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS MORTGAGE_OPS_EMAIL
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = 'Email notifications for Mortgage agent ops alerts';

-- ============================================================================
-- 8. ALERTS
-- ============================================================================

-- 8a. Latency Degradation Alert
CREATE OR REPLACE ALERT ALERT_LATENCY_DEGRADATION
  WAREHOUSE = MORTGAGE_WH
  SCHEDULE = '30 MINUTE'
  COMMENT = 'Fires when agent p95 latency exceeds 2x baseline in the last hour'
  IF (EXISTS (
    SELECT 1
    FROM (
        SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (
            ORDER BY RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER
        ) AS p95_ms
        FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
        WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
          AND RECORD:"name"::VARCHAR = 'AgentV2RequestResponseInfo'
          AND TIMESTAMP >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
    WHERE p95_ms > (SELECT LATENCY_P95_MS * 2 FROM MORTGAGE_DEMO_DB.OPS_MONITORING.BASELINE_METRICS LIMIT 1)
  ))
  THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
        SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
            '[MORTGAGE AGENT ALERT] Latency degradation detected. P95 latency in the last hour exceeds 2x baseline threshold.'
        ),
        SNOWFLAKE.NOTIFICATION.INTEGRATION('MORTGAGE_OPS_EMAIL'),
        SNOWFLAKE.NOTIFICATION.TARGET_TOPIC('ops_alerts'),
        '[ALERT] Mortgage Agent - Latency Degradation'
    );

-- 8b. Error Rate Alert
CREATE OR REPLACE ALERT ALERT_ERROR_SPIKE
  WAREHOUSE = MORTGAGE_WH
  SCHEDULE = '30 MINUTE'
  COMMENT = 'Fires when agent error rate exceeds 10% in the last hour'
  IF (EXISTS (
    SELECT 1
    FROM (
        SELECT
            COUNT_IF(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.tool.custom_tool.status"::VARCHAR = 'ERROR'
                OR RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.description"::VARCHAR = 'ERROR'
            ) AS errors,
            COUNT(*) AS total,
            ROUND(errors / NULLIF(total, 0) * 100, 2) AS error_rate
        FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
        WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
          AND RECORD:"name"::VARCHAR = 'AgentV2RequestResponseInfo'
          AND TIMESTAMP >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
    WHERE error_rate > 10 AND total >= 3
  ))
  THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
        SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
            '[MORTGAGE AGENT ALERT] Error rate spike detected. Error rate exceeds 10% in the last hour.'
        ),
        SNOWFLAKE.NOTIFICATION.INTEGRATION('MORTGAGE_OPS_EMAIL'),
        SNOWFLAKE.NOTIFICATION.TARGET_TOPIC('ops_alerts'),
        '[ALERT] Mortgage Agent - Error Rate Spike'
    );

-- 8c. Cost Alert
CREATE OR REPLACE ALERT ALERT_COST_SPIKE
  WAREHOUSE = MORTGAGE_WH
  SCHEDULE = '1440 MINUTE'
  COMMENT = 'Fires when daily MORTGAGE_WH credits exceed 2x baseline average'
  IF (EXISTS (
    SELECT 1
    FROM (
        SELECT SUM(CREDITS_USED) AS daily_credits
        FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
        WHERE WAREHOUSE_NAME = 'MORTGAGE_WH'
          AND START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    )
    WHERE daily_credits > (SELECT AVG_DAILY_CREDITS_MORTGAGE_WH * 2 FROM MORTGAGE_DEMO_DB.OPS_MONITORING.BASELINE_METRICS LIMIT 1)
  ))
  THEN
    CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
        SNOWFLAKE.NOTIFICATION.TEXT_PLAIN(
            '[MORTGAGE AGENT ALERT] Cost spike detected. Daily MORTGAGE_WH credit usage exceeds 2x baseline.'
        ),
        SNOWFLAKE.NOTIFICATION.INTEGRATION('MORTGAGE_OPS_EMAIL'),
        SNOWFLAKE.NOTIFICATION.TARGET_TOPIC('ops_alerts'),
        '[ALERT] Mortgage Agent - Cost Spike'
    );

-- ============================================================================
-- 9. HEALTH CHECK TASK (hourly)
-- ============================================================================
CREATE OR REPLACE TASK TASK_HEALTH_CHECK
  WAREHOUSE = MORTGAGE_WH
  SCHEDULE = '60 MINUTE'
  COMMENT = 'Hourly health check - materializes key metrics into HEALTH_CHECK_LOG'
AS
INSERT INTO MORTGAGE_DEMO_DB.OPS_MONITORING.HEALTH_CHECK_LOG
    (CHECK_TS, REQUESTS_LAST_HOUR, ERRORS_LAST_HOUR, P50_MS_LAST_HOUR, P95_MS_LAST_HOUR, ERROR_RATE_PCT)
WITH hourly AS (
    SELECT
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER AS duration_ms,
        CASE WHEN RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.description"::VARCHAR = 'ERROR' THEN 1 ELSE 0 END AS is_error
    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::VARCHAR = 'MORTGAGE_UNDERWRITING_ASSISTANT'
      AND RECORD:"name"::VARCHAR = 'AgentV2RequestResponseInfo'
      AND TIMESTAMP >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
)
SELECT
    CURRENT_TIMESTAMP(),
    COUNT(*),
    SUM(is_error),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_ms), 0),
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms), 0),
    ROUND(SUM(is_error) / NULLIF(COUNT(*), 0) * 100, 2)
FROM hourly;

-- ============================================================================
-- 10. TRANSFER OWNERSHIP AND START ALERTS/TASK
-- ============================================================================
GRANT OWNERSHIP ON ALERT MORTGAGE_DEMO_DB.OPS_MONITORING.ALERT_LATENCY_DEGRADATION TO ROLE MORTGAGE_OPS_MONITOR COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALERT MORTGAGE_DEMO_DB.OPS_MONITORING.ALERT_ERROR_SPIKE TO ROLE MORTGAGE_OPS_MONITOR COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ALERT MORTGAGE_DEMO_DB.OPS_MONITORING.ALERT_COST_SPIKE TO ROLE MORTGAGE_OPS_MONITOR COPY CURRENT GRANTS;
GRANT OWNERSHIP ON TASK MORTGAGE_DEMO_DB.OPS_MONITORING.TASK_HEALTH_CHECK TO ROLE MORTGAGE_OPS_MONITOR COPY CURRENT GRANTS;

USE ROLE MORTGAGE_OPS_MONITOR;
ALTER ALERT MORTGAGE_DEMO_DB.OPS_MONITORING.ALERT_LATENCY_DEGRADATION RESUME;
ALTER ALERT MORTGAGE_DEMO_DB.OPS_MONITORING.ALERT_ERROR_SPIKE RESUME;
ALTER ALERT MORTGAGE_DEMO_DB.OPS_MONITORING.ALERT_COST_SPIKE RESUME;
ALTER TASK MORTGAGE_DEMO_DB.OPS_MONITORING.TASK_HEALTH_CHECK RESUME;
