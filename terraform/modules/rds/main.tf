###############################################################################
# RDS module — managed Postgres with secrets from Secrets Manager
###############################################################################
resource "random_password" "master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "this" {
  identifier        = "${var.name}-db"
  engine            = var.engine
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.this.arn

  db_name                     = var.db_name
  username                    = "appadmin"
  password                    = random_password.master.result
  manage_master_user_password = false

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  backup_retention_period   = var.backup_retention
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot     = true
  deletion_protection       = var.multi_az
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-final-snapshot"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  tags                            = merge(var.tags, { Name = "${var.name}-db" })
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Allow Postgres from private app subnets only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-db-sg" })
}

resource "aws_security_group_rule" "db_ingress" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidrs
  security_group_id = aws_security_group.db.id
}

resource "aws_security_group_rule" "db_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db.id
}

resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.name} RDS storage encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = merge(var.tags, { Name = "${var.name}-rds-kms" })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name}-rds"
  target_key_id = aws_kms_key.this.key_id
}

# ---------------- Secrets Manager ----------------
resource "aws_secretsmanager_secret" "master" {
  name                    = "${var.name}-db-master"
  description             = "Master credentials for ${var.name} RDS"
  kms_key_id              = aws_kms_key.this.arn
  recovery_window_in_days = 7
  tags                    = merge(var.tags, { Name = "${var.name}-db-master-secret" })
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = "appadmin"
    password = random_password.master.result
    engine   = var.engine
    host     = aws_db_instance.this.address
    port     = 5432
    dbname   = var.db_name
  })
}
