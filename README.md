# Mortgage Underwriting Platform — Snowflake Data Platform

SI delivery project for a mortgage underwriting platform on Snowflake, featuring a Cortex Agent for automated policy compliance assessment.

## Project Overview

Building a mortgage underwriting data platform with real-time policy violation detection, dynamic PII masking, portfolio risk reporting, and an AI-powered underwriting assistant (Cortex Agent).

**Domain:** Mortgage Underwriting  
**Platform:** Snowflake  
**Database:** `MORTGAGE_DEMO_DB.MORTGAGE_DEMO`

## Sprint Board

[View on Jira](https://snowflakecomputing.atlassian.net/jira/software/projects/SLS/boards)

## Repo Structure

```
sql/
  00_infrastructure.sql        # Database, schema, warehouse, admin role
  01_create_tables.sql         # APPLICANT_PROFILES, LOAN_APPLICATIONS, EXCEPTION_LOGS
  02_load_data.sql             # Synthetic data generation
  03_create_procedure.sql      # FLAG_APPLICATION_EXCEPTION stored procedure
  04_cortex_search.sql         # PDF ingestion + Cortex Search Service
  05_create_agent.sql          # Cortex Agent (Mortgage Underwriting Assistant)
  06_create_semantic_view.sql  # Semantic view for Cortex Analyst
  07_grant_user_role.sql       # User role with read-only access
  08_teardown.sql              # Cleanup script
  09_data_policies.sql         # Masking + row access policies
  09_ops_monitoring.sql        # Agent observability alerts & health checks
  10_agent_budget.sql          # Cost controls for agent usage
  agent_spec.yaml              # Agent YAML specification
  mortgage_semantics.yaml      # Semantic view YAML definition
  pipelines/                   # Automated violation detection tasks
  governance/                  # Data masking & access policies
  compliance/                  # Regulatory breach detection views
  reporting/                   # Portfolio risk reports
  quality/                     # Data Metric Functions (DMFs)
scripts/
  deploy.sh                    # Deployment script
```

## Tech Stack

- **Snowflake** — Data warehouse, masking policies, row access policies
- **Snowflake Cortex Agent** — AI underwriting assistant with analyst + search tools
- **Cortex Search** — Policy document retrieval
- **Semantic Views** — Natural language to SQL for portfolio analytics
- **Data Metric Functions** — Automated data quality monitoring

## Setup

```bash
# Deploy sprint ticket SQL objects
bash scripts/deploy.sh
```

## Snowflake Intelligence Agent

The **Mortgage Underwriting Assistant** is deployed at:
`SNOWFLAKE_INTELLIGENCE.AGENTS.MORTGAGE_UNDERWRITING_ASSISTANT`

It can:
- Query applicant financials and loan metrics via semantic view
- Search lending policy documents (LTV, DTI, credit score thresholds)
- Flag applications for exception review via stored procedure
- Generate charts and visualizations
