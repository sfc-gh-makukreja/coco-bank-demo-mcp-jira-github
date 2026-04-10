-- Mortgage Underwriting Assistant: Load Synthetic Data
-- Run as MORTGAGE_AGENT_ADMIN role

USE ROLE MORTGAGE_AGENT_ADMIN;
USE DATABASE MORTGAGE_DEMO_DB;
USE SCHEMA MORTGAGE_DEMO;
USE WAREHOUSE MORTGAGE_WH;

-- Generate 100 Applicant Profiles
INSERT INTO APPLICANT_PROFILES (APPLICANT_ID, FULL_NAME, ANNUAL_INCOME, CREDIT_SCORE, EMPLOYMENT_TYPE, MONTHLY_DEBT_OBLIGATIONS)
SELECT
    'APL-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4()), 4, '0') AS APPLICANT_ID,
    CASE UNIFORM(1, 20, RANDOM())
        WHEN 1 THEN 'James Wilson'
        WHEN 2 THEN 'Sarah Chen'
        WHEN 3 THEN 'Michael O''Brien'
        WHEN 4 THEN 'Emily Patel'
        WHEN 5 THEN 'David Kim'
        WHEN 6 THEN 'Jessica Martinez'
        WHEN 7 THEN 'Robert Singh'
        WHEN 8 THEN 'Amanda Johnson'
        WHEN 9 THEN 'Daniel Lee'
        WHEN 10 THEN 'Rachel Thompson'
        WHEN 11 THEN 'Christopher Davis'
        WHEN 12 THEN 'Megan Brown'
        WHEN 13 THEN 'Andrew Garcia'
        WHEN 14 THEN 'Lauren Taylor'
        WHEN 15 THEN 'Matthew Anderson'
        WHEN 16 THEN 'Sophia Nguyen'
        WHEN 17 THEN 'William Robinson'
        WHEN 18 THEN 'Olivia White'
        WHEN 19 THEN 'Benjamin Harris'
        ELSE 'Natalie Clark'
    END || ' ' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4()), 3, '0') AS FULL_NAME,
    ROUND(UNIFORM(45000, 350000, RANDOM()), 2) AS ANNUAL_INCOME,
    UNIFORM(520, 850, RANDOM()) AS CREDIT_SCORE,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 7 THEN 'PAYG' ELSE 'Self-Employed' END AS EMPLOYMENT_TYPE,
    ROUND(UNIFORM(200, 5000, RANDOM()), 2) AS MONTHLY_DEBT_OBLIGATIONS
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- Generate 200 Loan Applications across the 100 applicants
INSERT INTO LOAN_APPLICATIONS (APPLICATION_ID, APPLICANT_ID, LOAN_AMOUNT, PROPERTY_VALUE, LOAN_PURPOSE, STATUS)
SELECT
    'APP-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4()) + 1000, 4, '0') AS APPLICATION_ID,
    'APL-' || LPAD(UNIFORM(1, 100, RANDOM()), 4, '0') AS APPLICANT_ID,
    ROUND(UNIFORM(150000, 1500000, RANDOM()), 2) AS LOAN_AMOUNT,
    ROUND(UNIFORM(200000, 2500000, RANDOM()), 2) AS PROPERTY_VALUE,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 6 THEN 'Owner-Occupier' ELSE 'Investment' END AS LOAN_PURPOSE,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'Approved'
        WHEN 2 THEN 'Approved'
        WHEN 3 THEN 'Approved'
        WHEN 4 THEN 'Declined'
        WHEN 5 THEN 'Declined'
        WHEN 6 THEN 'Exception Review'
        ELSE 'Pending'
    END AS STATUS
FROM TABLE(GENERATOR(ROWCOUNT => 200));
