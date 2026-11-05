# Backup & Recovery Plan — Task 1

## 1. Objectives

| | Target | Notes |
| --- | --- | --- |
| **RPO** (Recovery Point Objective) | ≤ 24 h for prod | Daily automated RDS backup; S3 versioning gives near-zero RPO for app code/logs |
| **RTO** (Recovery Time Objective) | ≤ 2 h for prod | Restore snapshot → new RDS → redeploy ASG (mostly automated) |

## 2. What is Backed Up

| Asset | Mechanism | Retention | Location |
| --- | --- | --- | --- |
| RDS Postgres data | Automated daily snapshot + transaction logs every 5 min | 1 day (dev) / 7 days (prod) | AWS-managed, in-region |
| RDS final snapshot | Manual trigger on `terraform destroy` | Indefinite until manually deleted | AWS-managed |
| S3 data bucket | Versioning + lifecycle (IA@30d, Glacier@90d) | 365 days + noncurrent versions 30 days | Same region |
| S3 access-log bucket | Versioning + lifecycle | 14 days | Same region |
| Secrets Manager secret | Automatic versioning on every `terraform apply` | 7-day recovery window | AWS-managed |
| Terraform state | Local file in `terraform/terraform.tfstate` (Phase 1) — move to S3+DynamoDB for prod (Phase 2) | Manual | Local or S3 |
| App source code | Git (GitHub) | Forever | GitHub |

## 3. Backup Schedule

```
Daily 03:00 IST    RDS automated backup window
Weekly Sun 04:30   RDS maintenance window (apply patches)
On terraform destroy   Final RDS snapshot named "<name>-final-snapshot"
Continuous         S3 PUT/DELETE creates object versions
On every apply     Secrets Manager secret gets a new version
```

## 4. Restore Procedures

### 4.1 Restore RDS from a snapshot

```bash
# 1. List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier arrowstack-t1-dev-db \
  --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
  --output table

# 2. Restore to a new instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier arrowstack-t1-dev-db-restored \
  --db-snapshot-identifier <snapshot-id> \
  --db-instance-class db.t3.micro \
  --db-subnet-group-name arrowstack-t1-dev-dbsng \
  --vpc-security-group-ids <db-sg-id>

# 3. Wait for available, then update Terraform to point at the new endpoint
aws rds wait db-instance-available --db-instance-identifier arrowstack-t1-dev-db-restored
terraform taint module.asg.aws_autoscaling_group.app   # forces rolling restart to pick up new DB
terraform apply
```

### 4.2 Restore an S3 object version

```bash
# List versions of an object
aws s3api list-object-versions \
  --bucket arrowstack-t1-dev-data-xxxxxxxx \
  --prefix app/app.tar.gz

# Restore a previous version
aws s3api get-object \
  --bucket arrowstack-t1-dev-data-xxxxxxxx \
  --key app/app.tar.gz \
  --version-id <version-id> \
  restored-app.tar.gz

# Re-upload as the latest
aws s3 cp restored-app.tar.gz s3://arrowstack-t1-dev-data-xxxxxxxx/app/app.tar.gz
```

### 4.3 Roll back Secrets Manager

```bash
# List versions
aws secretsmanager list-secret-version-ids --secret-id arrowstack-t1-dev-db-master

# Move the desired version to AWSCURRENT
aws secretsmanager update-secret-version-stage \
  --secret-id arrowstack-t1-dev-db-master \
  --version-stage AWSCURRENT \
  --move-to-version <version-id> \
  --remove-from-version <current-version-id>
```

## 5. DR Runbook — Instance Kill Drill

Goal: prove the architecture self-heals when an instance is killed.

```bash
# 1. Identify one app instance
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names arrowstack-t1-dev-asg \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

# 2. Watch the ALB healthy host count in another terminal
watch -n 5 "aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HealthyHostCount \
  --dimensions Name=LoadBalancer,Value=<alb-arn-suffix> \
  --start-time $(date -d '-10 minutes' -Iseconds) \
  --end-time $(date -Iseconds) --period 60 --statistics Average \
  --query 'Datapoints[-1:]' --output table"

# 3. Terminate the instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# 4. Within 90 s, the ALB marks it unhealthy; the ASG launches a replacement.
# 5. Confirm HealthyHostCount returns to ≥ 2 within 5 min.
```

## 6. DR Runbook — Full Region Loss (Phase 2 design)

Not yet implemented in Phase 1; planned approach:

1. Cross-region replication of S3 data bucket via `aws_s3_bucket_replication_configuration`.
2. Cross-region automated read replica of RDS via `aws_db_instance.replicate_source_db`.
3. Terraform workspace per region; `terraform apply -var="region=<region>"` to stand up the secondary.
4. Route 53 health-checked failover record between primary and secondary ALB.

## 7. Validation Cadence

| Test | Frequency | Owner | Evidence |
| --- | --- | --- | --- |
| Snapshot restore drill | Monthly | Intern | Runbook §4.1 executed; new RDS reachable |
| Instance kill drill | Per release | Intern | Runbook §5 executed; healthy count recovered |
| Secret rotation | Quarterly | Intern | New version created; app re-fetches on next launch |
| Backup existence check | Daily (automated) | CloudWatch alarm on `BackupRetentionPeriod < 1` | Alarm email |
