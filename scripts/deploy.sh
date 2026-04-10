#!/bin/bash
# Deploy all Snowflake objects for ANZ Banking project
# Usage: bash scripts/deploy.sh

set -e

CONNECTION=${SNOWFLAKE_CONNECTION_NAME:-"anz-banking"}

echo "Deploying ANZ Banking Co. Snowflake objects..."
echo "Connection: $CONNECTION"

echo "[1/5] Deploying masking policies..."
snow sql -c "$CONNECTION" -f sql/governance/pii_masking_policies.sql

echo "[2/5] Deploying transaction enrichment pipeline..."
snow sql -c "$CONNECTION" -f sql/pipelines/transaction_enrichment.sql

echo "[3/5] Deploying AML detection view..."
snow sql -c "$CONNECTION" -f sql/compliance/aml_detection.sql

echo "[4/5] Deploying credit risk report..."
snow sql -c "$CONNECTION" -f sql/reporting/credit_risk_report.sql

echo "[5/5] Deploying data quality DMFs..."
snow sql -c "$CONNECTION" -f sql/quality/banking_dmf_tests.sql

echo "Done!"
