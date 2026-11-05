###############################################################################
# IAM module — least-privilege EC2 instance profile for the app tier
###############################################################################
resource "aws_iam_role" "app" {
  name = "${var.name}-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-profile"
  role = aws_iam_role.app.name
  tags = var.tags
}

# ---------------- Policy: read app code from S3, write app logs to S3 ----------------
resource "aws_iam_role_policy" "s3_app" {
  name = "${var.name}-s3-app"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.data_bucket}/app/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl"]
        Resource = "arn:aws:s3:::${var.data_bucket}/logs/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.data_bucket}", "arn:aws:s3:::${var.log_bucket}"]
      }
    ]
  })
}

# ---------------- Policy: read DB secret from Secrets Manager ----------------
resource "aws_iam_role_policy" "secrets" {
  name = "${var.name}-secrets-read"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = var.secret_arn
    }]
  })
}

# ---------------- Policy: write CloudWatch Logs ----------------
resource "aws_iam_role_policy" "logs" {
  name = "${var.name}-cw-logs"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:*:*:log-group:/ec2/${var.name}*"
    }]
  })
}

# ---------------- Policy: read SSM parameter store (optional config) ----------------
resource "aws_iam_role_policy" "ssm" {
  name = "${var.name}-ssm-read"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:*:*:parameter/${var.name}/*"
    }]
  })
}

# ---------------- Policy: CloudWatch metrics (read-only) ----------------
resource "aws_iam_role_policy" "metrics_read" {
  name = "${var.name}-cw-metrics-read"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics"]
      Resource = "*"
    }]
  })
}
