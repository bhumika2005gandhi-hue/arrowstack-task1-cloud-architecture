# Architecture — Task 1 Multi-Tier Cloud Architecture

## 1. Conceptual Diagram

```
                         ┌──────────────────────────────────────────────┐
                         │                  Internet                    │
                         └──────────────────────────────────────────────┘
                                              │
                                              ▼
            ┌────────────────────────────────────────────────────────────────┐
            │            Application Load Balancer (public)                 │
            │   listeners :80 (HTTP)  → forward to app target group         │
            │   health check : GET /health on port 3000, 30 s interval       │
            │   access logs → S3 access-log bucket                          │
            └────────────────────────────────────────────────────────────────┘
                                              │ (only ALB SG → app SG :3000)
                                              ▼
            ┌────────────────────────────────────────────────────────────────┐
            │   Auto Scaling Group  (private subnets, 2 AZs)                │
            │   min=2  desired=2  max=4   t3.micro   Amazon Linux 2023      │
            │   ┌──────────┐         ┌──────────┐                            │
            │   │ EC2 app  │         │ EC2 app  │  ← sticky sessions (cookie)│
            │   └──────────┘         └──────────┘                            │
            │   scaling policy #1: target CPU = 60%                          │
            │   scaling policy #2: requests-per-target = 100                 │
            │   user-data: dnf install → cloudwatch agent → aws s3 cp        │
            │              app.tar.gz → secretsmanager get-secret-value      │
            │              → systemd unit app.service                        │
            └────────────────────────────────────────────────────────────────┘
                                              │ (app SG → db SG :5432 only)
                                              ▼
            ┌────────────────────────────────────────────────────────────────┐
            │   Amazon RDS Postgres 15  (database subnets, 2 AZs)           │
            │   db.t3.micro   storage 20 GB gp3, KMS-encrypted              │
            │   automated backup window 03:00 IST   retention 1d dev / 7d p │
            │   final snapshot on destroy                                     │
            │   master creds in Secrets Manager, fetched by EC2 at boot      │
            └────────────────────────────────────────────────────────────────┘

  Side services:
    • S3 data bucket (KMS, versioned, lifecycle → IA@30d, Glacier@90d, expire@365d)
        └ app/   ← user-data pulls app.tar.gz
        └ logs/  ← app writes structured logs
        └ backups/ ← manual DB dumps
    • S3 access-log bucket (KMS, expire@14d) ← ALB access logs
    • CloudWatch Logs: /ec2/<name>/app, /ec2/<name>/user-data, /vpc/<name>/flow-logs
    • CloudWatch Dashboard: 4 widgets — CPU, ALB 5xx, healthy hosts, p95 latency
    • CloudWatch Alarms → SNS topic → owner email: cpu>80% / 5xx>5 / unhealthy>0
    • IAM: app role (instance profile), bastion role, flow-log role
    • KMS: one key per RDS + one per S3 bucket, rotation enabled
    • NAT Gateway (1 in dev, per-AZ in prod) → IGW → internet
    • Optional Bastion host (public subnet, SSH 22 from allowed CIDRs)
```

## 2. Data Flow — A Single Request

1. Client resolves the ALB DNS to two public IPs (anycast).
2. Client opens a TCP connection to one of the ALB IPs on port 80.
3. ALB terminates HTTP, evaluates the listener rule (default: forward to app target group).
4. ALB picks a healthy target in the target group, preferentially in the same AZ for free cross-AZ traffic.
5. Target EC2 instance receives the request on port 3000 (the only inbound port allowed from the ALB SG).
6. Express app routes it (`/health`, `/`, `/items`, `/items/:id`).
7. If the route touches the DB, the app uses the pooled PG connection (creds from Secrets Manager at boot) on port 5432 to the RDS writer endpoint.
8. App returns JSON; ALB forwards to client.
9. Structured log line is appended to `/opt/app/app.log`, picked up by the CloudWatch agent, shipped to `/ec2/<name>/app`.

## 3. Why this Shape

- **Stateless app tier** → can scale and recover without session sync
- **DB in isolated subnet** → no path from the internet, only from app SG
- **Secrets Manager** → password rotation possible without code redeploy
- **Multi-AZ ASG** with `min=2` → survives single AZ failure
- **Target-tracking scaling** (not step) → no thrash, fewer moving parts
- **Access logs + VPC flow logs** → auditable, matches ISO 9001 evidence expectations
- **Cost tags everywhere** → Cost Explorer reports by project tag

## 4. Security Posture

| Layer | Control |
| --- | --- |
| Network | Public/private/DB subnet split; DB subnet has no IGW/NAT; SGs only allow least-necessary flows |
| Identity | EC2 role has 4 narrow policies: S3 app read, S3 log write, secret read, CW Logs write |
| Secrets | Random 24-char password in Secrets Manager, KMS-encrypted, fetched at boot only |
| Data at rest | RDS storage KMS-encrypted; S3 SSE-KMS with bucket keys; EBS encryption via KMS (recommended add) |
| Data in transit | ALB→target can be HTTPS by adding ACM cert + listener rule (Phase 2); RDS forces SSL via parameter group (recommended add) |
| Audit | VPC Flow Logs to CloudWatch; CloudTrail recommended at org level; S3 access logs via bucket policy |
| Patching | ASG instance refresh on new AMI; Amazon Linux 2023 default patch baseline |

## 5. Failure Modes & Response

| Failure | Detection | Response |
| --- | --- | --- |
| Single EC2 dies | ALB health check fails after 3×30 s = 90 s | Target marked unhealthy; ASG launches replacement; ALB stops sending traffic |
| AZ failure | ALB sees half targets unhealthy | ASG rebalances in surviving AZ (max=4 ensures headroom) |
| RDS failover (Multi-AZ prod) | RDS health check | Promotes standby in 60–120 s; app reconnects via pooled client |
| ALB 5xx spike | CloudWatch alarm | SNS email to owner; investigate access logs in S3 |
| NAT gateway failure | CloudWatch NAT gateway metrics | Replace EIP+gateway (or rely on second NAT in prod) |
| Secrets Manager outage | App boot fails | ASG keeps existing instances; new launches retry on next refresh |
