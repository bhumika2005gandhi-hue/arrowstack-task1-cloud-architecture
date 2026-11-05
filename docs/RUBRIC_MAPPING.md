# Rubric Mapping — Task 1 (100 points)

| Criterion | Points | Where to find evidence |
| --- | --- | --- |
| **Requirements & domain understanding** | 15 | `docs/REQUIREMENTS.md` §1–§4; `README.md` §1, §8 (design decisions); `docs/ARCHITECTURE.md` §3 (why this shape) |
| **Technical / professional execution** | 25 | `terraform/` (8 modules, all validated); `app/` (Node.js Express + Postgres pool); `terraform/modules/asg/user-data.sh` (bootstraps app, fetches secret, registers systemd); scaling policies CPU + ALB req-per-target |
| **Quality, accuracy & validation** | 20 | `tests/app.test.js` (4 endpoints × 5 cases); `tests/test_terraform.py` (fmt + init + validate); `docs/BACKUP_RECOVERY.md` §5 (kill drill); CloudWatch dashboard + 3 alarms |
| **Problem-solving & independence** | 15 | Resolved: stateless session problem (ALB cookie stickiness); secrets-not-in-tfstate problem (Secrets Manager + KMS); DB isolation problem (3 subnet tiers, SG rules); cost problem (single NAT, lifecycle rules, t3.micro). See `README.md` §8 + §10 |
| **Documentation & reproducibility** | 10 | `README.md` (deploy in 11 steps from blank AWS account); `terraform/terraform.tfvars.example`; `docs/REQUIREMENTS.md`, `docs/ARCHITECTURE.md`, `docs/BACKUP_RECOVERY.md`, `docs/COST_ANALYSIS.md`, this file |
| **Presentation & communication** | 10 | `docs/architecture.png`; clean repo layout (`README.md` §2); 2 LinkedIn demo posts in `download/linkedin-posts/`; viva answers in §2 below |
| **Creativity / improvement thinking** | 5 | `docs/ARCHITECTURE.md` §5 (failure modes table); `docs/COST_ANALYSIS.md` §3 (10 cost-awareness notes); `README.md` §10 (next steps); `docs/BACKUP_RECOVERY.md` §6 (Phase 2 multi-region design) |
| **Total** | **100** | |

## 2. Viva / Interview Answers

**Q1 — What business problem does the project solve, and how did you define success?**
A SaaS team needs a stateless business API that scales with traffic and survives instance failure. Success metrics (in `docs/REQUIREMENTS.md` §6): ALB 5xx < 0.5%, healthy host count ≥ `min_size`, auto-scaling response < 90 s, daily DB backup, recovery from instance kill < 5 min.

**Q2 — Which design decision had the biggest impact?**
Putting the database in an isolated subnet tier with no IGW/NAT, reachable only by the app SG on port 5432. This single choice eliminated an entire class of internet-facing DB attacks and made the security posture defensible to a reviewer.

**Q3 — How did you validate the quality?**
Three layers: (a) `tests/test_terraform.py` runs `terraform fmt`, `init`, `validate`; (b) `tests/app.test.js` smoke-tests four endpoints including error paths; (c) `docs/BACKUP_RECOVERY.md` §5 documents an instance-kill drill proving self-healing within 5 min.

**Q4 — What edge cases, limitations, risks did you identify?**
- Risk: single NAT in dev is an AZ-failure blast radius. Documented mitigation in `docs/ARCHITECTURE.md` §5.
- Risk: ALB→EC2 traffic is HTTP not HTTPS. Documented as Phase 2 (ACM cert + HTTPS listener).
- Limitation: no CI/CD; manual `terraform apply` only.
- Edge case: app boot failure → ASG marks instance unhealthy within 90 s; replacements launch.

**Q5 — What would you change for 10× traffic?**
- ASG `max_size` 4 → 40; switch from `t3.micro` to `c6i.large`.
- RDS `db.t3.micro` → Aurora Postgres with read replicas.
- Add CloudFront + WAF in front of ALB.
- Per-AZ NAT gateways.
- Multi-AZ ASG `min_size` 4 → spread across 3 AZs.
- Add ElastiCache for session/rate-limit.

**Q6 — How would you explain the project to a non-technical stakeholder?**
"Think of a shop's checkout counter. We need enough cashiers open during rush hours and few during quiet hours, so customers never wait too long — and if one cashier falls ill, another steps in automatically. This project builds exactly that for a software API: it adds cashiers (servers) when busy, removes them when quiet, and replaces any that fail, all automatically. The shop's data (customer records) is locked in a separate safe that only the cashiers can reach."

**Q7 — Which part required the most independent problem-solving?**
Designing the EC2 user-data so that the same script works for first-boot, instance refresh, and a manual re-run, without ever writing the DB password to disk in plaintext. The trick was to fetch the secret at boot via the IAM role and inject it directly into the systemd unit's Environment block, then reload systemd.
