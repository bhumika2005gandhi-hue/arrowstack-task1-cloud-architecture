#!/bin/bash
# ----------------------------------------------------------------------------
# EC2 user-data — bootstraps the Node.js Express sample app on Amazon Linux 2023
# Inputs (passed via templatefile): app_port, db_secret_arn, db_endpoint,
#                                   db_name, log_bucket, s3_app_key
# ----------------------------------------------------------------------------
set -euo pipefail
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

APP_PORT="${app_port}"
DB_SECRET_ARN="${db_secret_arn}"
DB_ENDPOINT="${db_endpoint}"
DB_NAME="${db_name}"
LOG_BUCKET="${log_bucket}"
S3_APP_KEY="${s3_app_key}"
APP_DIR="/opt/app"

# 1. System update + base deps
dnf -y update
dnf -y install nodejs npm git tar awscli postgresql15 || dnf -y install postgresql

# 2. CloudWatch agent
dnf -y install amazon-cloudwatch-agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/var/log/user-data.log", "log_group_name": "/ec2/${name}/user-data", "log_stream_name": "{instance_id}" },
          { "file_path": "/opt/app/app.log", "log_group_name": "/ec2/${name}/app", "log_stream_name": "{instance_id}" }
        ]
      }
    }
  }
}
EOF
systemctl enable --now amazon-cloudwatch-agent

# 3. Download app from S3
mkdir -p "$APP_DIR"
aws s3 cp "s3://$LOG_BUCKET/$S3_APP_KEY" "$APP_DIR/app.tar.gz" || echo "WARN: app archive not found in S3, will fall back to inline demo"
cd "$APP_DIR"
if [ -f app.tar.gz ]; then
  tar -xzf app.tar.gz
else
  # Minimal inline fallback so the ALB health check still passes
  npm init -y >/dev/null 2>&1
  npm install express pg >/dev/null 2>&1
  cat > server.js <<'JS'
const express = require("express");
const app = express();
const port = process.env.APP_PORT || 3000;
app.get("/health", (req, res) => res.json({ status: "ok", host: require("os").hostname() }));
app.get("/", (req, res) => res.json({ service: "arrowstack-t1-app", version: "1.0.0" }));
app.listen(port, () => console.log("listening on", port));
JS
fi

# 4. Resolve DB credentials from Secrets Manager
DB_USER=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text \
  | jq -r '.username')
DB_PASS=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text \
  | jq -r '.password')

# 5. Run app as systemd unit
cat > /etc/systemd/system/app.service <<EOF
[Unit]
Description=Arrowstack Task 1 sample app
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=APP_PORT=$APP_PORT
Environment=DB_HOST=$DB_ENDPOINT
Environment=DB_NAME=$DB_NAME
Environment=DB_USER=$DB_USER
Environment=DB_PASSWORD=$DB_PASS
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=append:$APP_DIR/app.log
StandardError=append:$APP_DIR/app.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now app

# 6. Sanity check
sleep 5
curl -fsS "http://127.0.0.1:$APP_PORT/health" || (echo "App did not come up" && exit 1)
