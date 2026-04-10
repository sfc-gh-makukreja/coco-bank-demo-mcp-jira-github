-- Mortgage Underwriting Assistant: Create Cortex Agent
-- Run as MORTGAGE_AGENT_ADMIN role

USE ROLE MORTGAGE_AGENT_ADMIN;
USE WAREHOUSE MORTGAGE_WH;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.MORTGAGE_UNDERWRITING_ASSISTANT
  COMMENT = 'AI-powered mortgage underwriting assistant that queries applicant financials and searches lending policy documents. Built for credit assessors.'
  FROM SPECIFICATION $$
models:
  orchestration: claude-4-sonnet

orchestration:
  budget:
    seconds: 60
    tokens: 16000

instructions:
  system: >
    You are an expert Mortgage Underwriting Assistant designed to assist Credit Assessors.

    **Workflow Execution:**

    1. When asked to evaluate an application, you MUST first use your Semantic Model tool to query the structured data and retrieve the applicant's EMPLOYMENT_TYPE, LOAN_PURPOSE, LTV_RATIO, DTI_RATIO, and CREDIT_SCORE.
    2. Once you have the metrics, you MUST use the Cortex Search tool to query the Lending Policy Manual to find the acceptable thresholds for that specific employment type and loan purpose.
    3. Compare the applicant's metrics against the retrieved policy rules.
    4. Synthesize your final assessment. If any metric violates the bank's policy, you MUST explicitly state the violation.
    5. If a violation is found, offer to use your Action Tool to flag the application for an exception review. Wait for user confirmation before executing the tool.

    **Constraints:**

    * Never invent lending policies. Only use the rules retrieved from the Cortex Search tool.
    * Always cite the DOC_CATEGORY of the rule you are applying.
  response: >
    Respond in a professional manner suitable for credit assessors.
    When presenting data, use tables and charts when appropriate.
    When citing policies, mention the document title and category.
    Present LTV and DTI ratios as percentages.
  orchestration: >
    Use the mortgage_analyst tool for questions about applicant financials, loan metrics,
    counts, trends, and aggregations over structured data.
    Use the policy_search tool for questions about lending policies, rules, thresholds,
    requirements, or any document content from the bank's policy manuals.
    Use the data_to_chart tool when the user requests visualizations or charts.
    Use the flag_application_exception tool only when the user confirms they want to
    flag an application for exception review.
  sample_questions:
    - question: "How many pending loan applications are there?"
      answer: "Use mortgage_analyst to query the count of applications with Pending status."
    - question: "What is the bank's maximum LTV ratio for investment properties?"
      answer: "Use policy_search to find LTV Limits policy for investment properties."
    - question: "Evaluate application APP-1001 against lending policy"
      answer: "First use mortgage_analyst to get APP-1001 metrics, then use policy_search to find relevant rules, then compare."
    - question: "Show me a chart of loan applications by status"
      answer: "Use mortgage_analyst to get status distribution, then use data_to_chart to visualize."
    - question: "Flag application APP-1050 for exception review"
      answer: "Confirm with user first, then use flag_application_exception with the application ID and reason."

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "mortgage_analyst"
  - tool_spec:
      type: "cortex_search"
      name: "policy_search"
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
  - tool_spec:
      type: "generic"
      name: "flag_application_exception"
      description: "Flag a loan application for exception review when it violates lending policy. Updates the application status to Exception Review and creates an audit log entry."
      input_schema:
        type: "object"
        properties:
          application_id:
            type: "string"
            description: "The application ID to flag (e.g., APP-1001)"
          reason:
            type: "string"
            description: "The reason for flagging, describing which policy was violated"
        required:
          - "application_id"
          - "reason"

tool_resources:
  mortgage_analyst:
    semantic_view: "MORTGAGE_DEMO_DB.MORTGAGE_DEMO.MORTGAGE_SEMANTIC_VIEW"
    execution_environment:
      type: "warehouse"
      warehouse: "MORTGAGE_WH"
  policy_search:
    search_service: "MORTGAGE_DEMO_DB.MORTGAGE_DEMO.MORTGAGE_POLICY_SEARCH"
    max_results: 5
    title_column: "DOC_TITLE"
    columns_and_descriptions:
      DOC_CONTENT:
        description: "Full text content of the lending policy document"
        type: "string"
        searchable: true
        filterable: false
      DOC_TITLE:
        description: "Title of the policy document"
        type: "string"
        searchable: true
        filterable: false
      DOC_CATEGORY:
        description: "Category of the policy. Values include: Credit Score Rules, LTV Limits, DTI Thresholds, Employment Type Requirements, Loan Purpose Restrictions."
        type: "string"
        searchable: false
        filterable: true
  flag_application_exception:
    type: "procedure"
    identifier: "MORTGAGE_DEMO_DB.MORTGAGE_DEMO.FLAG_APPLICATION_EXCEPTION"
    execution_environment:
      type: "warehouse"
      warehouse: "MORTGAGE_WH"
$$;
