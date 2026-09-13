#!/usr/bin/env bash

set -euo pipefail

AWS_REGION="us-east-1"
PROJECT="enterprise-platform"
ENVIRONMENT="dev"
SERVICE="payment-service"

SECRET_NAME="${PROJECT}/${ENVIRONMENT}/${SERVICE}"

echo "=========================================="
echo " AWS Secrets Manager"
echo "=========================================="
echo
echo "Secret: ${SECRET_NAME}"
echo "Region: ${AWS_REGION}"
echo

read -r -p "Database username: " DB_USERNAME
read -r -s -p "Database password: " DB_PASSWORD
echo
read -r -s -p "JWT secret: " JWT_SECRET
echo

SECRET_JSON=$(jq -n \
  --arg username "$DB_USERNAME" \
  --arg password "$DB_PASSWORD" \
  --arg jwt "$JWT_SECRET" \
  '{
    "database-username": $username,
    "database-password": $password,
    "jwt-secret": $jwt
  }')

if aws secretsmanager describe-secret \
    --secret-id "${SECRET_NAME}" \
    --region "${AWS_REGION}" \
    >/dev/null 2>&1; then

    echo
    echo "Secret exists."
    echo "Updating secret value..."

    aws secretsmanager put-secret-value \
      --secret-id "${SECRET_NAME}" \
      --secret-string "${SECRET_JSON}" \
      --region "${AWS_REGION}"

else

    echo
    echo "Secret does not exist."
    echo "Creating secret..."

    aws secretsmanager create-secret \
      --name "${SECRET_NAME}" \
      --description "Secrets for ${SERVICE} in ${ENVIRONMENT}" \
      --secret-string "${SECRET_JSON}" \
      --region "${AWS_REGION}"
fi

unset DB_USERNAME
unset DB_PASSWORD
unset JWT_SECRET
unset SECRET_JSON

echo
echo "=========================================="
echo " Secret configured successfully"
echo "=========================================="
echo
echo "AWS Secret:"
echo "  ${SECRET_NAME}"