# Cost Analysis — Task 1

All prices are **ap-south-1 (Mumbai)** list prices in **USD**, as of Nov 2026.
Verify current pricing at <https://aws.amazon.com/pricing/>.

## 1. Dev environment (this configuration as-shipped)

| Resource | Qty | Unit price (USD/hr) | Monthly (730 h) |
| --- | --- | --- | --- |
| EC2 `t3.micro` (app) | 2 | 0.0084 | $12.26 |
| NAT Gateway | 1 | 0.045 | $32.85 |
| NAT Gateway data processing | ~10 GB | 0.045/GB | $0.45 |
| RDS `db.t3.micro` Postgres (Single-AZ) | 1 | 0.022 | $16.06 |
| RDS storage gp3 20 GB | 20 GB | 0.090/GB-mo | $1.80 |
| ALB | 1 | 0.0225 + $0.008/LCU-hr | ~$19.71 |
| S3 data bucket (assume 2 GB) | 2 GB | 0.023/GB-mo | $0.05 |
| S3 requests (PUT/GET/LIST) | — | — | ~$0.50 |
| S3 access-log bucket (assume 1 GB) | 1 GB | 0.023/GB-mo | $0.02 |
| KMS keys | 2 | $1.00/key-mo | $2.00 |
| Secrets Manager API calls (assume 1k/mo) | — | $0.05/10k | ~$0.01 |
| CloudWatch Logs ingestion (assume 1 GB/mo) | 1 GB | $0.50/GB | $0.50 |
| CloudWatch dashboards | 1 | $3.00/mo | $3.00 |
| SNS emails | ~100 | free tier | $0.00 |
| VPC Flow Logs (assume 1 GB/mo) | 1 GB | $0.50/GB | $0.50 |
| **Total dev** | | | **~$90/mo** |

> Free-tier tip: if your account is within its first 12 months, EC2 `t3.micro` (750 h/mo) and RDS `db.t3.micro` (750 h/mo) are partially covered — net dev cost can drop to ~$60/mo.

## 2. Prod environment (target shape)

| Resource | Qty | Notes |
| --- | --- | --- |
| EC2 `t3.small` × 4 (min 4) | 4 | HA across 2 AZ |
| NAT Gateway | 2 (per-AZ) | Survives AZ failure |
| RDS `db.t3.medium` Multi-AZ | 1 pair | Synchronous standby |
| ALB | 1 | + ACM cert (free), + WAF ($5/rule/mo + $0.60/million req) |
| S3 + KMS + CloudWatch | same as dev but higher log volume | |

Rough prod monthly: **~$300–$450/mo** depending on traffic and log volume.

## 3. Cost-Awareness Notes (the brief requires these)

1. **Single NAT in dev** — saves ~$32/mo vs per-AZ. Acceptable because the only NAT-using path is private EC2 → S3/Secrets Manager; AZ failure just shifts traffic to the surviving AZ.
2. **`t3.micro` not `t3.small` in dev** — meets free-tier; CPU credits replenish when idle.
3. **S3 lifecycle** — `STANDARD_IA` after 30 days, `GLACIER` after 90 days, expire at 365 days. Cuts S3 cost by ~80% for cold data.
4. **CloudWatch Logs retention 14 days** — log ingestion is the silent cost; keeping it short caps monthly spend.
5. **Spot Instances for non-prod ASG** — switch `instance_type` and add `mixed_instances_policy` with `Spot` for ~70% EC2 savings in dev (not in default config because spot can be reclaimed mid-request).
6. **RDS storage 20 GB** — minimum allowed by AWS; grows automatically if needed.
7. **No CloudFront in dev** — only add CDN when traffic patterns justify it (see Task 3 brief).
8. **No AWS Shield Advanced** — $3,000/mo commitment; only justified for high-exposure apps.
9. **Cost tags applied via provider `default_tags`** — every resource carries `Project=Arrowstack-Task1-CloudArchitecture`, `Owner=...`, `Environment=...`. Use Cost Explorer to filter.
10. **Tear down when not in use** — `terraform destroy` over weekends during dev. Saves ~$22/day.

## 4. Estimated Budget Alerts

Add these to `main.tf` if you want proactive alerting:

```hcl
resource "aws_budgets_budget" "monthly" {
  name         = "arrowstack-t1-monthly"
  budget_type  = "COST"
  limit_amount = "100"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  cost_filters = { TagKeyValue = ["Project$Arrowstack-Task1-CloudArchitecture"] }
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }
}
```
