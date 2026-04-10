# agents.md — Mortgage Underwriting Platform

## Project Overview

SI delivery project: a mortgage underwriting data platform on Snowflake with a Cortex Agent for automated policy compliance assessment.

- **Domain:** Mortgage Underwriting (Australian banking — APRA CPS 234 compliance)
- **Platform:** Snowflake
- **Database:** `MORTGAGE_DEMO_DB.MORTGAGE_DEMO`
- **Warehouse:** `MORTGAGE_WH` (XSMALL, auto-suspend 60s)
- **Admin role:** `MORTGAGE_AGENT_ADMIN`
- **User role:** `MORTGAGE_USER_ROLE` (read-only)
- **Jira project:** coco-bank-demo-mcp-jira-github ([board](https://snowflakecomputing.atlassian.net/jira/software/c/projects/SLS/boards/8203))
- **GitHub repo:** `coco-bank-demo-mcp-jira-github`

## Repo Structure

```
sql/
  00_infrastructure.sql          # Database, schema, warehouse, admin role (run as ACCOUNTADMIN)
  01_create_tables.sql           # APPLICANT_PROFILES, LOAN_APPLICATIONS, EXCEPTION_LOGS
  02_load_data.sql               # Synthetic data generation
  03_create_procedure.sql        # FLAG_APPLICATION_EXCEPTION stored procedure
  04_cortex_search.sql           # PDF ingestion + Cortex Search Service
  05_create_agent.sql            # Cortex Agent creation
  06_create_semantic_view.sql    # Semantic view for Cortex Analyst
  07_grant_user_role.sql         # User role with read-only access
  08_teardown.sql                # Cleanup / drop all objects
  09_data_policies.sql           # Masking + row access policies
  09_ops_monitoring.sql          # Agent observability alerts & health checks
  10_agent_budget.sql            # Cost controls for agent usage
  agent_spec.yaml                # Cortex Agent YAML specification
  mortgage_semantics.yaml        # Semantic view YAML definition
  pipelines/
    transaction_enrichment.sql   # Automated loan violation detection task (SLS-2)
  governance/
    pii_masking_policies.sql     # Dynamic PII masking (SLS-3)
  compliance/
    aml_detection.sql            # Lending compliance breach detection view (SLS-4)
  reporting/
    credit_risk_report.sql       # Portfolio risk report (SLS-5)
  quality/
    banking_dmf_tests.sql        # Data quality DMFs (SLS-6)
scripts/
  deploy.sh                     # Deploys sprint SQL objects via snow CLI
```

## Snowflake Objects

### Tables
| Table | Description |
|---|---|
| `APPLICANT_PROFILES` | Borrower demographics: name, employment type, income, credit score, monthly debt |
| `LOAN_APPLICATIONS` | Loan requests: amount, property value, purpose (Owner-Occupier / Investment), status |
| `EXCEPTION_LOGS` | Audit trail when applications are flagged for exception review |

### Key Metrics
- **LTV Ratio:** `ROUND(LOAN_AMOUNT / NULLIF(PROPERTY_VALUE, 0) * 100, 2)` — Loan-to-Value percentage
- **DTI Ratio:** `ROUND((MONTHLY_DEBT_OBLIGATIONS * 12) / NULLIF(ANNUAL_INCOME, 0) * 100, 2)` — Debt-to-Income percentage
- Application statuses: `Pending`, `Approved`, `Declined`, `Exception Review`

### Cortex Agent
- **Name:** Mortgage Underwriting Assistant
- **Location:** `SNOWFLAKE_INTELLIGENCE.AGENTS.MORTGAGE_UNDERWRITING_ASSISTANT`
- **Tools:**
  - `mortgage_analyst` — Cortex Analyst (text-to-SQL) backed by semantic view
  - `policy_search` — Cortex Search over lending policy PDFs
  - `data_to_chart` — Visualization tool
  - `flag_application_exception` — Calls stored procedure to flag violations

### Cortex Search Service
- **Name:** `MORTGAGE_DEMO_DB.MORTGAGE_DEMO.MORTGAGE_POLICY_SEARCH`
- **Content:** Lending policy PDFs (Credit Score Rules, LTV Limits, DTI Thresholds, Employment Type Requirements, Loan Purpose Restrictions)

### Semantic View
- **Name:** `MORTGAGE_DEMO_DB.MORTGAGE_DEMO.MORTGAGE_SEMANTIC_VIEW`
- **Definition:** `sql/mortgage_semantics.yaml`
- **Joins:** `LOAN_APPLICATIONS` many-to-one `APPLICANT_PROFILES` on `APPLICANT_ID`

## Dev Environment

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- `snow` CLI installed and configured
- Connection name: `admin` (default) — set via `SNOWFLAKE_CONNECTION_NAME` env var

### Deployment
```bash
# Full platform setup (run numbered scripts in order)
snow sql -c admin -f sql/00_infrastructure.sql
snow sql -c admin -f sql/01_create_tables.sql
# ... through 10_agent_budget.sql

# Sprint ticket objects only
bash scripts/deploy.sh
```

### Teardown
```bash
snow sql -c admin -f sql/08_teardown.sql
```

## SQL Conventions

- All SQL runs under `MORTGAGE_AGENT_ADMIN` role (except `00_infrastructure.sql` which uses `ACCOUNTADMIN`)
- Use `CREATE OR REPLACE` for idempotent deployments
- Stored procedures use `LANGUAGE SQL` with `BEGIN...END` blocks — reference variables with colon prefix (`:my_var`) inside SQL statements
- Numbered prefix (`00_`, `01_`, ...) indicates execution order for full setup
- Sprint-specific SQL goes in subdirectories (`pipelines/`, `governance/`, `compliance/`, `reporting/`, `quality/`)

## Jira Integration

- **Project:** coco-bank-demo-mcp-jira-github
- **Ticket naming:** SQL files in subdirectories map to Jira tickets (see `deploy.sh` for mapping)
- **Workflow:** Backlog -> In Progress -> Done
- When completing a ticket, update Jira status and commit with the ticket key in the message

## Testing

- Validate SQL compiles before committing: use `snow sql` with the admin connection
- Agent spec changes: re-run `05_create_agent.sql` to redeploy
- Semantic view changes: update `mortgage_semantics.yaml` then re-run `06_create_semantic_view.sql`
- DMF tests are in `sql/quality/banking_dmf_tests.sql`

## PR Guidelines

- Branch per Jira ticket (e.g., `sls-2-violation-detection`)
- Commit messages reference the Jira ticket key (e.g., `SLS-2: Add violation detection task`)
- Keep SQL files idempotent — safe to re-run
