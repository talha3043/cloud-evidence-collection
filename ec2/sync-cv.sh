#!/bin/bash
BUCKET="cv-23l-3043"
PREFIX="site/"
DEST="/var/www/html"
LOG="/var/log/cv-sync.log"

# Fetch IMDSv2 token and instance ID
TOKEN=$(curl -s -S -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
INSTANCE_ID=$(curl -s -S -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

# Sync files from S3 to webroot
if aws s3 sync "s3://${BUCKET}/${PREFIX}" "$DEST" --delete; then
    sed -i "s|{{HOSTED_ON}}|EC2 ${INSTANCE_ID}|g" "${DEST}/index.html"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sync SUCCESS" >> "$LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sync FAILED" >> "$LOG"
fi
