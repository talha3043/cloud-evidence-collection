#!/bin/bash
dnf update -y
dnf install -y httpd cronie awscli

# Setup sync script
mkdir -p /opt/cv
cat << 'EOF' > /opt/cv/sync-cv.sh
#!/bin/bash
BUCKET="cv-23l-3043"
PREFIX="site/"
DEST="/var/www/html"
LOG="/var/log/cv-sync.log"

TOKEN=$(curl -s -S -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
INSTANCE_ID=$(curl -s -S -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")

if aws s3 sync "s3://${BUCKET}/${PREFIX}" "$DEST" --delete; then
    sed -i "s|{{HOSTED_ON}}|EC2 ${INSTANCE_ID}|g" "${DEST}/index.html"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sync SUCCESS" >> "$LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sync FAILED" >> "$LOG"
fi
EOF

chmod +x /opt/cv/sync-cv.sh
touch /var/log/cv-sync.log
chmod 666 /var/log/cv-sync.log

# Schedule cron every 5 minutes
echo "*/5 * * * * root /opt/cv/sync-cv.sh" > /etc/cron.d/cv-sync
systemctl enable --now crond

# Start webserver and run initial sync
systemctl enable --now httpd
/opt/cv/sync-cv.sh
