#!/bin/bash
# Deploy sprint ticket Snowflake objects for Mortgage Underwriting Platform
# Usage: bash scripts/deploy.sh

set -e

CONNECTION=${SNOWFLAKE_CONNECTION_NAME:-"admin"}

echo "Deploying Mortgage Underwriting Platform sprint objects..."
echo "Connection: $CONNECTION"

echo "[1/5] Deploying PII masking policies (SLS-3)..."
snow sql -c "$CONNECTION" -f sql/governance/pii_masking_policies.sql

echo "[2/5] Deploying loan violation detection pipeline (SLS-2)..."
snow sql -c "$CONNECTION" -f sql/pipelines/transaction_enrichment.sql

echo "[3/5] Deploying lending compliance breach view (SLS-4)..."
snow sql -c "$CONNECTION" -f sql/compliance/aml_detection.sql

echo "[4/5] Deploying portfolio risk report (SLS-5)..."
snow sql -c "$CONNECTION" -f sql/reporting/credit_risk_report.sql

echo "[5/5] Deploying data quality DMFs (SLS-6)..."
snow sql -c "$CONNECTION" -f sql/quality/banking_dmf_tests.sql

echo "Done!"
