#!/usr/bin/env bash
set -euo pipefail

DINERO_REGION="us-east-1"
DINERO_REPOSITORY="dinero-api"
DINERO_FUNCTION="dinero-api"
DINERO_ROLE_NAME="dinero-lambda-execution-role"
DINERO_IMAGE_TAG="latest"
DINERO_TRUST_POLICY="$(mktemp)"
trap 'rm -f "$DINERO_TRUST_POLICY"' EXIT

export AWS_REGION="$DINERO_REGION"
export AWS_DEFAULT_REGION="$DINERO_REGION"
export AWS_PAGER=""

cat > "$DINERO_TRUST_POLICY" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON

DINERO_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
DINERO_ECR_HOST="${DINERO_ACCOUNT_ID}.dkr.ecr.${DINERO_REGION}.amazonaws.com"
DINERO_IMAGE_URI="${DINERO_ECR_HOST}/${DINERO_REPOSITORY}:${DINERO_IMAGE_TAG}"

if ! aws ecr describe-repositories --repository-names "$DINERO_REPOSITORY" >/dev/null 2>&1; then
  aws ecr create-repository \
    --repository-name "$DINERO_REPOSITORY" \
    --image-scanning-configuration scanOnPush=true >/dev/null
fi

aws ecr get-login-password | docker login \
  --username AWS \
  --password-stdin "$DINERO_ECR_HOST"

docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --load \
  --tag "$DINERO_IMAGE_URI" .
docker push "$DINERO_IMAGE_URI"

if ! aws iam get-role --role-name "$DINERO_ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role \
    --role-name "$DINERO_ROLE_NAME" \
    --assume-role-policy-document "file://${DINERO_TRUST_POLICY}" >/dev/null
fi

aws iam attach-role-policy \
  --role-name "$DINERO_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

DINERO_ROLE_ARN="$(aws iam get-role \
  --role-name "$DINERO_ROLE_NAME" \
  --query 'Role.Arn' \
  --output text)"

if aws lambda get-function --function-name "$DINERO_FUNCTION" >/dev/null 2>&1; then
  aws lambda update-function-code \
    --function-name "$DINERO_FUNCTION" \
    --image-uri "$DINERO_IMAGE_URI" >/dev/null
  aws lambda wait function-updated --function-name "$DINERO_FUNCTION"
else
  # IAM role changes can take a few seconds to become available to Lambda.
  sleep 10
  aws lambda create-function \
    --function-name "$DINERO_FUNCTION" \
    --package-type Image \
    --code "ImageUri=${DINERO_IMAGE_URI}" \
    --role "$DINERO_ROLE_ARN" \
    --architectures x86_64 \
    --memory-size 512 \
    --timeout 30 >/dev/null
  aws lambda wait function-active-v2 --function-name "$DINERO_FUNCTION"
fi

aws lambda update-function-configuration \
  --function-name "$DINERO_FUNCTION" \
  --memory-size 512 \
  --timeout 30 >/dev/null
aws lambda wait function-updated --function-name "$DINERO_FUNCTION"

echo "Dinero Lambda deployment complete."
echo "Region: ${DINERO_REGION}"
echo "Function: ${DINERO_FUNCTION}"
echo "Image: ${DINERO_IMAGE_URI}"
