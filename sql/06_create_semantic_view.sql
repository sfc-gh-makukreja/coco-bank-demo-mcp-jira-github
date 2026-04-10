-- Mortgage Underwriting Assistant: Create Semantic View
-- Run as MORTGAGE_AGENT_ADMIN role
-- Requires: mortgage_semantics.yaml in same directory

USE ROLE MORTGAGE_AGENT_ADMIN;
USE WAREHOUSE MORTGAGE_WH;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;

-- Create semantic view from YAML
-- Note: The YAML content is embedded inline below.
-- If running manually, paste the contents of mortgage_semantics.yaml between the $$ delimiters.
CREATE OR REPLACE SEMANTIC VIEW MORTGAGE_DEMO_DB.MORTGAGE_DEMO.MORTGAGE_SEMANTIC_VIEW
  AS SELECT SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML($$
name: mortgage_semantics
tables:
  - name: applicant_profiles
    base_table:
      database: MORTGAGE_DEMO_DB
      schema: MORTGAGE_DEMO
      table: APPLICANT_PROFILES
    dimensions:
      - name: APPLICANT_ID
        synonyms:
          - "applicant identifier"
        expr: APPLICANT_ID
        data_type: VARCHAR
        description: "Unique identifier for each applicant (e.g., APL-0001)"
      - name: FULL_NAME
        synonyms:
          - "applicant name"
          - "borrower name"
        expr: FULL_NAME
        data_type: VARCHAR
        description: "Full name of the applicant"
      - name: EMPLOYMENT_TYPE
        synonyms:
          - "job type"
          - "employment status"
        expr: EMPLOYMENT_TYPE
        data_type: VARCHAR
        description: "Type of employment: PAYG or Self-Employed"
    measures:
      - name: ANNUAL_INCOME
        synonyms:
          - "yearly income"
          - "salary"
        expr: ANNUAL_INCOME
        data_type: NUMBER
        description: "Applicant annual income in dollars"
      - name: CREDIT_SCORE
        synonyms:
          - "FICO"
          - "FICO score"
          - "credit rating"
        expr: CREDIT_SCORE
        data_type: NUMBER
        description: "Applicant credit score (300-850 range)"
      - name: MONTHLY_DEBT_OBLIGATIONS
        synonyms:
          - "monthly debt"
          - "debt payments"
        expr: MONTHLY_DEBT_OBLIGATIONS
        data_type: NUMBER
        description: "Total monthly debt obligation amount in dollars"

  - name: loan_applications
    base_table:
      database: MORTGAGE_DEMO_DB
      schema: MORTGAGE_DEMO
      table: LOAN_APPLICATIONS
    dimensions:
      - name: APPLICATION_ID
        synonyms:
          - "application number"
          - "app ID"
        expr: APPLICATION_ID
        data_type: VARCHAR
        description: "Unique identifier for each loan application (e.g., APP-1001)"
      - name: APPLICANT_ID
        synonyms:
          - "applicant identifier"
        expr: APPLICANT_ID
        data_type: VARCHAR
        description: "Foreign key to applicant_profiles"
      - name: LOAN_PURPOSE
        synonyms:
          - "purpose of loan"
          - "loan type"
        expr: LOAN_PURPOSE
        data_type: VARCHAR
        description: "Purpose of the loan: Owner-Occupied, Investment, or Refinance"
      - name: STATUS
        synonyms:
          - "application status"
          - "loan status"
        expr: STATUS
        data_type: VARCHAR
        description: "Current status: Pending, Approved, Declined, or Exception Review"
      - name: LTV_RATIO
        synonyms:
          - "LTV"
          - "loan to value"
          - "loan-to-value ratio"
        expr: "ROUND(LOAN_AMOUNT / NULLIF(PROPERTY_VALUE, 0) * 100, 2)"
        data_type: NUMBER
        description: "Loan-to-Value ratio as a percentage (loan_amount / property_value * 100)"
      - name: DTI_RATIO
        synonyms:
          - "DTI"
          - "debt to income"
          - "debt-to-income ratio"
        expr: "ROUND((applicant_profiles.MONTHLY_DEBT_OBLIGATIONS * 12) / NULLIF(applicant_profiles.ANNUAL_INCOME, 0) * 100, 2)"
        data_type: NUMBER
        description: "Debt-to-Income ratio as a percentage ((monthly_debt * 12) / annual_income * 100)"
    measures:
      - name: LOAN_AMOUNT
        synonyms:
          - "loan value"
          - "mortgage amount"
        expr: LOAN_AMOUNT
        data_type: NUMBER
        description: "Requested loan amount in dollars"
      - name: PROPERTY_VALUE
        synonyms:
          - "property price"
          - "home value"
        expr: PROPERTY_VALUE
        data_type: NUMBER
        description: "Appraised property value in dollars"

relationships:
  - name: loan_to_applicant
    left_table: loan_applications
    right_table: applicant_profiles
    relationship_columns:
      - left_column: APPLICANT_ID
        right_column: APPLICANT_ID
    join_type: many_to_one
    relationship_type: many_to_one
$$);
