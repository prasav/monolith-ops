# Architecture Overview

## Three Clouds, One Control Plane

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CLIENT REQUESTS                                     │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLOUDFLARE (Free Tier)                               │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────────┐   │
│  │    DNS      │  │   Tunnel     │  │ Zero Trust │  │      R2          │   │
│  │  CNAMEs →   │  │  (2 tunnels) │  │  Access    │  │  State + Backups │   │
│  │  Tunnels    │  │              │  │  (Email)   │  │  10GB, 0 egress  │   │
│  └─────────────┘  └──────────────┘  └────────────┘  └──────────────────┘   │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
              ┌───────────────────┴───────────────────┐
              ▼                                       ▼
┌─────────────────────────────────┐   ┌─────────────────────────────────────────┐
│     ORACLE CLOUD (Always Free)  │   │         GCP (Always Free)               │
│  ┌───────────────────────────┐  │   │  ┌─────────────────────────────────┐   │
│  │  Ampere A1 Flex (2c/12GB) │  │   │  │  e2-micro (0.25 vCPU/1GB)       │   │
│  │  200GB Block + 10TB egress│  │   │  │  30GB disk                      │   │
│  │                           │  │   │  │                                 │   │
│  │  ┌─────────────────────┐  │  │   │  │  ┌───────────────────────────┐  │   │
│  │  │ Coolify (PaaS)      │  │  │   │  │  │ Beszel (metrics)          │  │   │
│  │  │   :8000             │  │  │   │  │  │  :8090                     │  │   │
│  │  ├─────────────────────┤  │  │   │  │  ├───────────────────────────┤  │   │
│  │  │ n8n + Postgres      │  │  │   │  │  │ Uptime Kuma (health)      │  │   │
│  │  │   :5678             │  │  │   │  │  │  :3001                     │  │   │
│  │  ├─────────────────────┤  │  │   │  │  ├───────────────────────────┤  │   │
│  │  │ Gitea + Postgres    │  │  │   │  │  │ systemd timers:           │  │   │
│  │  │   :3000/:222        │  │  │   │  │  │  - nightly backup → R2    │  │   │
│  │  ├─────────────────────┤  │  │   │  │  │  - 6hr plan → tofu        │  │   │
│  │  │ Vaultwarden         │  │  │   │  │  └───────────────────────────┘  │   │
│  │  │   :8080             │  │  │   │                                   │   │
│  │  ├─────────────────────┤  │   │  ┌─────────────────────────────────┐  │   │
│  │  │ Jellyfin (Direct)   │  │   │  │ Cloud Run (2M req/mo)         │  │   │
│  │  │   :8096             │  │   │  │  min-instances=0              │  │   │
│  │  └─────────────────────┘  │   │  ├─────────────────────────────────┤  │   │
│  │                           │  │  │ Firestore (1GB) + Auth (50k)    │  │   │
│  │  Tailscale Exit Node      │  │  │ BigQuery (1TB/mo)               │  │   │
│  │  cloudflared Tunnel       │  │  │ Cloud Build (120 min/day)       │  │   │
│  └───────────────────────────┘  │   │  └─────────────────────────────────┘  │   │
└─────────────────────────────────┘   └─────────────────────────────────────────┘
              │                                       │
              └───────────────────┬───────────────────┘
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      TAILSCALE MESH (Free, 100 devices)                    │
│  Oracle A1 ↔ GCP micro ↔ Your devices                                       │
│  Subnet routers, exit nodes, MagicDNS                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

1. **Client → Cloudflare DNS** → CNAME to Tunnel
2. **Cloudflare Tunnel** → Terminates TLS, forwards to origin via cloudflared
3. **Zero Trust Access** → Checks email/OIDC, allows/denies
4. **Origin (Oracle/GCP)** → Services respond via Docker/Cloud Run
5. **Tailscale** → Private mesh for admin, backups, inter-service

## State Management

| Component | State Location | Backup |
|-----------|---------------|--------|
| OpenTofu | R2 bucket `monolith-ops-state` | Versioned in R2 |
| n8n Postgres | Oracle A1 volume | Nightly pg_dump → R2 |
| Gitea Postgres | Oracle A1 volume | Nightly gitea dump → R2 |
| Vaultwarden SQLite | Oracle A1 volume | Nightly copy → R2 |
| Coolify | Oracle A1 volume | Nightly coolify backup → R2 |
| Beszel | GCP micro volume | Config in tofu |
| Uptime Kuma | GCP micro volume | SQLite in docker volume |

## Cost Breakdown (Monthly)

| Service | Free Tier Limit | Our Usage | Cost |
|---------|----------------|-----------|------|
| Oracle A1 | 2 OCPU / 12 GB | 2 OCPU / 12 GB | $0 |
| Oracle Block | 200 GB | ~100 GB | $0 |
| Oracle Egress | 10 TB | <1 TB | $0 |
| GCP e2-micro | 1 instance (US) | 1 instance | $0 |
| Cloud Run | 2M req/mo | <100k | $0 |
| Firestore | 1 GB + 50k MAU | <100 MB | $0 |
| BigQuery | 1 TB queries | <10 GB | $0 |
| Cloud Build | 120 min/day | <30 min | $0 |
| Cloudflare Tunnel | Unlimited | 2 tunnels | $0 |
| Cloudflare R2 | 10 GB + 0 egress | ~5 GB | $0 |
| Cloudflare Workers | 100k/day | <1k | $0 |
| Cloudflare Pages | Unlimited | 1 site | $0 |
| Cloudflare Zero Trust | 50 seats | 1 seat | $0 |
| Tailscale | 100 devices | <10 | $0 |
| **Total** | | | **$0** |