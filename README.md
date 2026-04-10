# ANZ Banking Co. — Snowflake Data Platform

SI delivery project for ANZ Banking Co.'s enterprise data platform on Snowflake.

## Project Overview

Migrating core banking data workloads to Snowflake, enabling real-time transaction analytics, regulatory compliance reporting, and AI-powered fraud detection.

**Customer:** ANZ Banking Co. (fictitious)  
**SI Partner:** Qrious (NZ)  
**Platform:** Snowflake on AWS ap-southeast-2 (Sydney)

## Sprint Board

[View on Jira](https://snowflakecomputing.atlassian.net/jira/software/projects/SLS/boards)

## Repo Structure

```
sql/
  pipelines/       # Streams & Tasks for real-time ingestion
  governance/      # Data masking & access policies
  compliance/      # AML & regulatory reporting
  reporting/       # Business intelligence views
  quality/         # Data Metric Functions (DMFs)
scripts/           # Deployment & utility scripts
```

## Tech Stack

- **Snowflake** — Data warehouse, Streams, Tasks, Dynamic Tables
- **Snowflake Cortex** — AI/ML for fraud detection & document processing
- **dbt** — Transformation layer
- **GitHub Actions** — CI/CD pipeline

## Setup

```bash
# Configure Snowflake connection
snow connection add

# Deploy all objects
bash scripts/deploy.sh
```
