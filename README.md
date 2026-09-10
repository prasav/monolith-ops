# monolith-ops

Infrastructure-as-code control plane for Oracle Cloud (compute), GCP (serverless), and Cloudflare (edge/CDN/Zero Trust). Single repo, OpenTofu, zero recurring cost.

**monolith-ops** — the load-bearing infrastructure behind a USD-facing freelance automation agency. Three free tiers, one control plane, no monthly bill.

* **Oracle Cloud Always Free** — 2 Ampere A1 OCPUs, 12 GB RAM, 200 GB block, 10 TB/mo egress → runs Coolify + n8n + Postgres + Vaultwarden + Gitea on a single ARM VM
* **Google Cloud Always Free** — e2-micro watchdog + Cloud Run (2M req/mo) + Firestore + BigQuery 1 TB/mo + Cloud Build 120 min/day → trusted IPs, serverless demos, analytics portfolio, nightly backups
* **Cloudflare Free** — Tunnel, Zero Trust Access, Pages, Workers (100k/day), R2 (10 GB, zero egress), Email Routing → front door, TLS, auth, edge compute, off-site backup target

Managed from one GCP e2-micro via cron + Gitea Actions. OpenTofu for provisioning, Beszel + Uptime Kuma for observability.

---

## Repo Structure

```
monolith-ops/
├── tofu/
│   ├── oci/          # Oracle Cloud resources
│   ├── gcp/          # GCP resources
│   └── cloudflare/   # Cloudflare resources
├── scripts/          # Backup, bootstrap, maintenance
├── docs/             # Architecture, runbooks
└── Makefile          # Unified apply/plan/destroy
```

---

## Quick Start

```bash
# Install OpenTofu
# https://opentofu.org/docs/intro/install/

# Configure providers (one-time)
export OCI_TENANCY_OCID=...
export OCI_USER_OCID=...
export OCI_FINGERPRINT=...
export OCI_PRIVATE_KEY_PATH=...
export OCI_REGION=...

export GOOGLE_CREDENTIALS=$(cat gcp-sa.json)
export GOOGLE_PROJECT=...
export GOOGLE_REGION=us-central1

export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_ACCOUNT_ID=...

# Initialize all providers
make init

# Plan all
make plan

# Apply all
make apply

# Or per-cloud
make plan-oci apply-oci
make plan-gcp apply-gcp
make plan-cloudflare apply-cloudflare
```

---

## Provider Versions

Pinned in each module's `versions.tf` for reproducibility.

---

## State Backend

Cloudflare R2 (S3-compatible, zero egress) — one bucket `monolith-ops-state`, no lock server needed.

---

## Control Plane

* **Runner**: GCP e2-micro (us-central1) — systemd timers for nightly plan/backup
* **CI**: Gitea Actions on Oracle A1 (ARM) — `gitea-act-runner`
* **Observability**: Beszel (metrics) + Uptime Kuma (health) on GCP micro
* **Backups**: Nightly `pg_dump` + `rclone` → R2 + GCP Storage

---

## Cost Guards

* OCI Budget Alert: $1 → Telegram
* GCP Budget Alert: $1 → Telegram
* Cloudflare Usage Notifications → Telegram

---

## License

MIT