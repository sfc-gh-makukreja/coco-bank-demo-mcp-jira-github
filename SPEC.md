# Snowflake Intelligence: Mortgage Underwriting Assistant Specification

Version: 1.0

Purpose: Define the architecture, data models, and agent orchestration for a Snowflake Intelligence demonstration that automates mortgage loan assessments.

## 1. Problem Statement

Mortgage loan assessment requires credit assessors to perform complex evaluations by cross-referencing hard quantitative data (applicant financials, Loan-to-Value ratios) against dense, unstructured qualitative constraints (bank lending policies, risk appetite statements).

Currently, this requires assessors to manually pull structured data from traditional databases and manually search through PDF policy manuals to ensure compliance.

This project solves this operational bottleneck by leveraging Snowflake Intelligence to:

* Expose structured database records via a natural-language Semantic Model (Cortex Analyst).
* Index and retrieve unstructured policy documents via Retrieval-Augmented Generation (Cortex Search).
* Orchestrate these capabilities using an autonomous AI Agent (Cortex Agents) to synthesize policy decisions and trigger downstream operational actions.

## 2. Goals and Non-Goals

### 2.1 Goals

* Build an end-to-end Snowflake AI demonstration using synthetic mortgage data.
* Implement using Cortex Code Skills that are available for any number of tasks e.g. data to agent demo build, semantic view creation, cortex agent test and so on.
* Make sure to note what skills are available and are relevant for the sub-tasks.
* Implement Cortex Analyst with a strictly defined YAML semantic model mapping financial terms to SQL.
* Use of Cortex AI Function to parse and chunk pdf documents.
* Implement Cortex Search to provide semantic retrieval over chunked lending policy text.
* Create a multi-tool Cortex Agent with a deterministic system prompt to synthesize data and rules.
* Register a Python Stored Procedure as a custom tool to allow the Agent to take write-actions (flagging exceptions).
* Generate scripts whether SQL/ Python in the local dir, and execute them with snowflake_sql_execute tool one by one.

### 2.2 Non-Goals

* Production deployment or integration with real core banking systems (e.g., Temenos, Mambu).
* Ingestion of real Personally Identifiable Information (PII) or real credit histories.
* General-purpose chat unrelated to the mortgage underwriting domain.

## 3. System Overview

> **Execution pattern:** This demo follows the `data-to-agent` skill pipeline. Refer to SKILL.md Steps 1–7 for the generic execution flow. This section describes only the domain-specific components. Use cortex search docs for documentation search outside sandbox with admin connection. Use cortex reflect for semantic view YAML validation outside sandbox with admin connection. If the data to agent skill's generate_pdfs.py Python script fails due to proxy issues, then first generate the PDFs locally, then try the SQL PUT command instead via snowflake_sql_execute tool to upload them to the stage, and finally parse with AI_PARSE_DOCUMENT.
### 3.1 Domain Components

1. **Structured Data** — `APPLICANT_PROFILES` and `LOAN_APPLICATIONS` tables with synthetic mortgage data (credit scores, LTV ratios, DTI ratios).

2. **Semantic Layer** — A semantic view mapping financial terms (LTV, DTI, FICO) to SQL, enabling natural-language queries over mortgage data.

3. **Policy Documents** — Five PDF lending policy manuals covering credit score rules, LTV limits, DTI thresholds, employment type requirements, and loan purpose restrictions.

4. **Cortex Search** — `MORTGAGE_POLICY_SEARCH` service indexing parsed policy documents for semantic retrieval by category.

5. **Custom Action** — `FLAG_APPLICATION_EXCEPTION` stored procedure allowing the agent to flag applications that violate lending policy.

6. **Agent** — `MORTGAGE_UNDERWRITING_ASSISTANT` orchestrating all tools under a strict system prompt that enforces policy-based assessment workflow.

## 4. Core Domain Model

### 4.1 Entities

#### 4.1.1 Applicant Profile

Normalized record of the individual applying for the loan.

* `APPLICANT_ID` (VARCHAR, PK): Stable internal identifier.
* `FULL_NAME` (VARCHAR): Synthesized human-readable name.
* `ANNUAL_INCOME` (NUMBER): Base yearly income.
* `CREDIT_SCORE` (NUMBER): Integer between 300 and 850.
* `EMPLOYMENT_TYPE` (VARCHAR): Enum `['PAYG', 'Self-Employed']`.
* `MONTHLY_DEBT_OBLIGATIONS` (NUMBER): Existing debt servicing costs.

#### 4.1.2 Loan Application

Normalized record of the requested financial product.

* `APPLICATION_ID` (VARCHAR, PK): Stable ticket identifier (e.g., `APP-1002`).
* `APPLICANT_ID` (VARCHAR, FK): Links to Applicant Profile.
* `LOAN_AMOUNT` (NUMBER): Requested principal.
* `PROPERTY_VALUE` (NUMBER): Assessed collateral value.
* `LOAN_PURPOSE` (VARCHAR): Enum `['Owner-Occupier', 'Investment']`.
* `STATUS` (VARCHAR): Enum `['Pending', 'Approved', 'Declined', 'Exception Review']`.

#### 4.1.3 Mortgage Document

Parsed document from the bank's lending policy PDFs, stored for Cortex Search indexing.

* `DOC_FILENAME` (VARCHAR): Original filename of the PDF on stage.
* `DOC_CONTENT` (VARCHAR): Full parsed text content of the document.
* `DOC_TITLE` (VARCHAR): Human-readable document title.
* `DOC_CATEGORY` (VARCHAR): Metadata filter (e.g., `Credit Score Rules`, `LTV Limits`).

#### 4.1.4 Exception Log

Audit trail of actions taken by the Agent.

* `LOG_ID` (VARCHAR, PK): Auto-increment or UUID.
* `APPLICATION_ID` (VARCHAR, FK): The flagged application.
* `FLAG_REASON` (VARCHAR): AI-generated synthesis of why the policy was failed.
* `TIMESTAMP` (TIMESTAMP_NTZ): Execution time.

## 5. Workflow and Configuration Specification

### 5.1 Cortex Analyst: Semantic Model (`mortgage_semantics.yaml`)

**Purpose:** Provide the Agent with a deterministic translation layer for querying structured metrics.

**Schema Requirements:**

* **Tables:** Must expose `APPLICANT_PROFILES` and `LOAN_APPLICATIONS`.
* **Joins:** Must define the join path on `APPLICANT_ID`.
* **Calculated Dimensions:**
  * `LTV_RATIO`: Defined as `LOAN_AMOUNT / PROPERTY_VALUE`.
  * `DTI_RATIO`: Defined as `(MONTHLY_DEBT_OBLIGATIONS * 12) / ANNUAL_INCOME`.
* **Synonyms:**
  * `CREDIT_SCORE` -> "FICO", "credit rating"
  * `LTV_RATIO` -> "LTV", "loan to value"
  * `DTI_RATIO` -> "DTI", "debt to income"
  * `EMPLOYMENT_TYPE` -> "job type", "employment status"

### 5.2 Cortex Search: Retrieval Service

> **Implementation:** See `data-to-agent` SKILL.md Step 4c for generic Cortex Search creation pattern.

* **Source Table:** `MORTGAGE_DOCUMENTS`
* **Search Column:** `DOC_CONTENT`
* **Filter Attributes:** `DOC_TITLE`, `DOC_CATEGORY`
* **Service Name:** `MORTGAGE_POLICY_SEARCH`

### 5.3 Custom Action Tool: Exception Flagging

**Purpose:** Allow the agent to mutate state when an application violates policy.

**Stored Procedure Signature:**

```sql
CREATE OR REPLACE PROCEDURE FLAG_APPLICATION_EXCEPTION(application_id VARCHAR, reason VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
```
**Execution Logic:**

1. Validates `application_id` exists in `LOAN_APPLICATIONS`.
2. Updates `LOAN_APPLICATIONS.STATUS` to `'Exception Review'`.
3. Inserts a record into `EXCEPTION_LOGS` with the `application_id`, `reason`, and `CURRENT_TIMESTAMP()`.
4. Returns a human-readable success string: `"Application {application_id} successfully flagged for review."`

## 6. Agent Orchestration State

### 6.1 Agent Metadata

Every Cortex Agent must include descriptive metadata so it is identifiable in the Snowflake Intelligence UI:

* **`COMMENT`**: A plain-text description of the agent's purpose, capabilities, and domain. This appears in admin views and helps operators understand what the agent does.
* **`PROFILE`**: A JSON object with:
  * `display_name`: Human-friendly name shown to end users in the Snowflake Intelligence UI.
  * `color`: Theme color for the agent card (e.g., `"blue"`, `"green"`, `"red"`).

### 6.2 Agent System Prompt (Policy Layer)

The Cortex Agent must be configured with the following strict orchestration instructions to prevent hallucination and enforce logical routing:

> "You are an expert Mortgage Underwriting Assistant designed to assist Credit Assessors.
>
> **Workflow Execution:**
>
> 1. When asked to evaluate an application, you MUST first use your Semantic Model tool to query the structured data and retrieve the applicant's `EMPLOYMENT_TYPE`, `LOAN_PURPOSE`, `LTV_RATIO`, `DTI_RATIO`, and `CREDIT_SCORE`.
> 2. Once you have the metrics, you MUST use the Cortex Search tool to query the Lending Policy Manual to find the acceptable thresholds for that specific employment type and loan purpose.
> 3. Compare the applicant's metrics against the retrieved policy rules.
> 4. Synthesize your final assessment. If any metric violates the bank's policy, you MUST explicitly state the violation.
> 5. If a violation is found, offer to use your Action Tool to flag the application for an exception review. Wait for user confirmation before executing the tool.
>
> **Constraints:**
>
> * Never invent lending policies. Only use the rules retrieved from the Cortex Search tool.
> * Always cite the `DOC_CATEGORY` of the rule you are applying."

### 6.2 Agent Tool Configuration

> **Implementation:** See `data-to-agent` SKILL.md Step 6 for generic agent creation patterns, tool_spec rules, and YAML structure.

| Tool Name | Type | Domain Purpose |
|---|---|---|
| `mortgage_analyst` | `cortex_analyst_text_to_sql` | Queries applicant financials (LTV, DTI, credit scores) |
| `policy_search` | `cortex_search` | Searches lending policy rules by category |
| `data_to_chart` | `data_to_chart` | Visualizes portfolio distributions and risk metrics |
| `flag_application_exception` | `generic` (stored procedure) | Flags applications violating lending policy |

**Domain-specific resource mapping:**
* `mortgage_analyst` → `MORTGAGE_SEMANTIC_VIEW`
* `policy_search` → `MORTGAGE_POLICY_SEARCH` (use `search_service` field, NOT `name`)
* `flag_application_exception` → `FLAG_APPLICATION_EXCEPTION(VARCHAR, VARCHAR)`

## 7. Snowflake Intelligence Integration

> **Implementation:** See `data-to-agent` SKILL.md Step 6 for generic SI registration pattern.

The agent must be registered in the Snowflake Intelligence object (`SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT`) so credit assessors can access it without SQL knowledge via the curated UI.

## 8. Access Control (RBAC)

> **Implementation:** See `data-to-agent` SKILL.md Step 2 (role-first infrastructure) and Step 7 (user role grants) for the generic 3-phase role creation pattern.

### 8.1 Roles

| Role | Purpose |
|---|---|
| `MORTGAGE_AGENT_ADMIN` | Full CRUD, agent management, monitoring, SI management |
| `MORTGAGE_AGENT_USER` | Read-only data access, agent usage |

### 8.2 Key Privilege Requirements

**Admin Role (`MORTGAGE_AGENT_ADMIN`):**

* `USAGE` + `MODIFY` + `MONITOR` on the Agent (enables editing and viewing monitoring data)
* `MODIFY` + `USAGE` on the Snowflake Intelligence object (enables adding/removing agents)
* `USAGE` on warehouse, database, schema, Cortex Search service
* `SELECT` on semantic view, all tables
* `CREATE` privileges on schema objects (tables, views, procedures, stages, search services, semantic views)
* `INSERT`, `UPDATE`, `DELETE` on all tables
* `SNOWFLAKE.CORTEX_USER` database role

**User Role (`MORTGAGE_AGENT_USER`):**

* `USAGE` on the Agent (query only)
* `USAGE` on the Snowflake Intelligence object (view curated agent list)
* `USAGE` on warehouse, database, schema, Cortex Search service
* `SELECT` on semantic view, all tables
* `SNOWFLAKE.CORTEX_USER` database role

## 9. Execution Parameters

These values are passed to the `data-to-agent` skill pipeline during execution. They map to the `<PARAMETER>` placeholders in SKILL.md.

| Parameter | Value |
|---|---|
| `DOMAIN` | `MORTGAGE` |
| `DATABASE` | `MORTGAGE_DEMO_DB` |
| `SCHEMA` | `MORTGAGE_DEMO` |
| `WAREHOUSE` | `MORTGAGE_WH` |
| `AGENT_NAME` | `MORTGAGE_UNDERWRITING_ASSISTANT` |
| `SEMANTIC_VIEW_NAME` | `MORTGAGE_SEMANTIC_VIEW` |
| `SEARCH_SERVICE` | `MORTGAGE_POLICY_SEARCH` |
| `CONNECTION` | `admin` |
| `ADMIN_CONNECTION` | `admin` |
| `USER` | `MKUKREJA` |
| `AGENT_DESCRIPTION` | AI-powered mortgage underwriting assistant that queries applicant financials and searches lending policy documents. Built for credit assessors. |
| `AGENT_DISPLAY_NAME` | Mortgage Underwriting Assistant |

## 10. Acceptance Testing

> **Implementation:** See `data-to-agent` SKILL.md testing steps for the generic testing framework. This section defines the domain-specific test cases.

### 10.1 Semantic View Validation (Pre-Agent)

Validate the semantic view compiles and answers basic queries before creating the agent:

| # | Test Question | Expected Behavior |
|---|---|---|
| 1 | "How many loan applications are there?" | Returns count from `LOAN_APPLICATIONS` |
| 2 | "What is the average credit score?" | Returns AVG from `APPLICANT_PROFILES` |
| 3 | "Show me applicants with LTV ratio above 80%" | Uses calculated `LTV_RATIO` dimension |

### 10.2 Agent Testing (Post-Creation, 5 Questions)

Test the agent with questions spanning all tool types:

| # | Test Question | Tools Expected | Pass Criteria |
|---|---|---|---|
| 1 | "How many pending loan applications are there?" | `mortgage_analyst` | Returns correct count, cites SQL |
| 2 | "What is the bank's policy on maximum LTV ratio for investment properties?" | `policy_search` | Returns policy text with `DOC_CATEGORY` citation |
| 3 | "Evaluate application APP-1001 against lending policy" | `mortgage_analyst` + `policy_search` | Retrieves applicant data, then searches relevant policy rules, synthesizes assessment |
| 4 | "Show me a chart of loan applications by status" | `mortgage_analyst` + `data_to_chart` | Returns data and renders a visualization |
| 5 | "Flag application APP-1050 for exception review with reason: LTV exceeds policy limit" | `flag_application_exception` | Confirms flagging, updates `EXCEPTION_LOGS` table |

### 10.3 User-Role Acceptance Testing (Post-Grants)

Switch to the user role and verify read-only access works:

| # | Test | Expected Result |
|---|---|---|
| 1 | `USE ROLE MORTGAGE_AGENT_USER` then query agent | Agent responds normally |
| 2 | Query semantic view directly | Returns data (SELECT granted) |
| 3 | Attempt `INSERT INTO LOAN_APPLICATIONS ...` | Permission denied (read-only) |
| 4 | Attempt `DROP TABLE APPLICANT_PROFILES` | Permission denied (no CREATE/DROP) |