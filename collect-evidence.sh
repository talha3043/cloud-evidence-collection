#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <bucket-name> <ec2-http-url> <lambda-https-url>"
    exit 1
fi

BUCKET="$1"
EC2_URL="$2"
LAMBDA_URL="$3"
OUTPUT="evidence.txt"

exec > "$OUTPUT" 2>&1

echo "== caller =="
aws sts get-caller-identity || echo "Command failed"

echo "== public-access =="
aws s3api get-public-access-block --bucket "$BUCKET" || echo "Command failed"

echo "== versioning =="
aws s3api get-bucket-versioning --bucket "$BUCKET" || echo "Command failed"

echo "== objects =="
aws s3 ls "s3://${BUCKET}/site/" || echo "Command failed"

echo "== ec2-policy =="
ROLE_NAME=$(aws iam list-roles --query "Roles[?contains(RoleName, 'cv-ec2-role')].RoleName | [0]" --output text)
POLICY_NAME=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query "PolicyNames[0]" --output text)
aws iam get-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY_NAME" || echo "Command failed"

echo "== lambda-policy =="
LAMBDA_ROLE=$(aws iam list-roles --query "Roles[?contains(RoleName, 'cv-lambda-role')].RoleName | [0]" --output text)
aws iam list-attached-role-policies --role-name "$LAMBDA_ROLE" || echo "Command failed"
LAMBDA_INLINE=$(aws iam list-role-policies --role-name "$LAMBDA_ROLE" --query "PolicyNames[0]" --output text)
aws iam get-role-policy --role-name "$LAMBDA_ROLE" --policy-name "$LAMBDA_INLINE" || echo "Command failed"

echo "== security-group =="
SG_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*cv-ec2*" --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" --output text)
aws ec2 describe-security-groups --group-ids "$SG_ID" --query "SecurityGroups[0].IpPermissions" || echo "Command failed"

echo "== instance =="
aws ec2 describe-instances --filters "Name=tag:Name,Values=*cv-ec2*" --query "Reservations[0].Instances[0].[InstanceType, MetadataOptions.HttpTokens, IamInstanceProfile.Arn]" || echo "Command failed"

echo "== endpoints =="
echo "Testing EC2 Endpoint:"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${EC2_URL}/"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${EC2_URL}/style.css"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${EC2_URL}/cv.pdf"

echo "Testing Lambda Endpoint:"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${LAMBDA_URL}/"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${LAMBDA_URL}/style.css"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${LAMBDA_URL}/cv.pdf"
curl -s -o /dev/null -w "Status: %{http_code}, Content-Type: %{content_type}\n" "${LAMBDA_URL}/random-page"

echo "Testing Direct S3 (Expected 403):"
curl -s -o /dev/null -w "Status: %{http_code}\n" "https://${BUCKET}.s3.amazonaws.com/site/index.html"

echo "== lambda-logs =="
aws logs tail "/aws/lambda/cv-func-23l-3043" --since 10m || echo "Command failed"

echo "== log-retention =="
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/cv-func-23l-3043" --query "logGroups[0].[logGroupName, retentionInDays]" || echo "Command failed"

exec 1>&-
echo "DONE"
