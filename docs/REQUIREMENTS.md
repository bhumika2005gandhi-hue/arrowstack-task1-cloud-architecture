# Requirements & Acceptance Criteria — Task 1

## 1. Stakeholder & Business Use Case

| Item | Value |
| --- | --- |
| Primary stakeholder | A SaaS product team running a customer-facing business API |
| Decision enabled | "Can we ship a stateless API tier that scales with traffic and survives instance failure?" |
| Measurable benefit | ≥ 99.9% availability, p95 latency < 200 ms, automatic recovery from instance loss in < 90 s |

## 2. Scope

**In scope**
- Network, compute, data, storage and observability layers for one API tier in one AWS region.
- IaC via Terraform, sample Node.js app, automated tests, runbook.

**Out of scope**
- Multi-region active-active (Phase 2)
- CI/CD pipeline (Phase 2)
- Migration tooling for an existing on-prem database

## 3. Inputs, Outputs, Constraints

| | |
| --- | --- |
| **Inputs** | Terraform variables (region, instance type, ASG bounds, DB class), AWS account credentials |
| **Outputs** | Internet-facing ALB URL, RDS endpoint, S3 buckets, CloudWatch dashboard URL |
| **Constraints** | AWS free-tier friendly budget (< $20/month dev); reproducible by a mentor in < 60 min; never commit secrets |

## 4. Required Features (Arrowstack Task 1 brief) → Implementation

| Required feature | Where |
| --- | --- |
| IAM least privilege | `terraform/modules/iam/` — app role can only: read S3 `app/*`, write S3 `logs/*`, read Secrets Manager secret, write CloudWatch Logs to `/ec2/<name>/*`, read SSM params under `/<name>/*`, read CW metrics |
| Configuration / secrets management | `terraform/modules/rds/` Secrets Manager secret, KMS key, fetched by EC2 user-data; no plaintext in tfstate |
| Monitoring / logging | `terraform/modules/cloudwatch/` — log groups, dashboard (CPU, 5xx, healthy hosts, p95), 3 alarms wired to SNS email |
| Backup / recovery plan | `docs/BACKUP_RECOVERY.md` + RDS automated backups (1-day dev / 7-day prod), final snapshot on destroy, S3 versioning |
| Cost-awareness notes | `docs/COST_ANALYSIS.md` — line-item monthly estimate, free-tier tips, prod upgrade path |

## 5. Acceptance Criteria (from brief, §13)

1. ✅ All core requirements completed and mapped to evidence — see §4 above
2. ✅ Reproducible by a mentor — `terraform init && terraform apply` after editing tfvars; README §4 walks through it
3. ✅ Quality checks/tests/validation documented — `tests/app.test.js`, `tests/test_terraform.py`; major issues disclosed in README §10
4. ✅ Professionally organised, consistently named — see repository layout in README §2
5. ✅ Intern can explain key decisions, trade-offs, limitations, future improvements — README §8 and §10

## 6. Success Metrics (how we will measure)

| Metric | Target | How measured |
| --- | --- | --- |
| ALB 5xx rate | < 0.5% of requests | CloudWatch `HTTPCode_ELB_5XX_Count` |
| Healthy host count | ≥ `min_size` (2) at all times | CloudWatch `HealthyHostCount` |
| Auto-scaling response time | New instance InService within 90 s of alarm | ASG activity history |
| RDS automated backup | 1 daily snapshot retained ≥ 1 day | `aws rds describe-db-snapshots` |
| Recovery from instance kill | ALB health green within 90 s | Manual drill — see `BACKUP_RECOVERY.md` §5 |
