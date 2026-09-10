# Runbooks

## Daily Operations

### Check Health
```bash
# From GCP e2-micro
make plan                    # Check infrastructure drift
curl -s https://beszel.yourdomain.com/api/health  # Beszel health
curl -s https://status.yourdomain.com/api/health  # Uptime Kuma health
```

### View Logs
```bash
# Oracle A1 services
ssh ubuntu@oracle-a1 "docker logs -f n8n --tail 100"
ssh ubuntu@oracle-a1 "docker logs -f coolify --tail 100"
ssh ubuntu@oracle-a1 "docker logs -f gitea --tail 100"

# GCP e2-micro
docker logs -f uptime-kuma --tail 100
journalctl -u monolith-backup -f
journalctl -u monolith-plan -f
```

---

## Incident Response

### Oracle A1 Unreachable
1. Check OCI Console → Instance state
2. If **Stopped**: Start instance (idle reclamation)
3. If **Terminated**: Recreate from tofu (`make apply-oci`), restore from R2 backups
4. If **Running but no SSH**: Check NSG rules, UFW, Cloudflare Tunnel
5. **Capacity error**: Try different AD, or upgrade to PAYG temporarily

### Cloudflare Tunnel Down
```bash
# On Oracle A1
systemctl status cloudflared-oracle
journalctl -u cloudflared-oracle -f

# Restart
systemctl restart cloudflared-oracle

# On GCP micro
systemctl restart cloudflared-gcp
```

### Backup Failed
```bash
# Check rclone
rclone lsd r2:

# Check R2 bucket
# Cloudflare Dashboard → R2 → monolith-ops-backups

# Manual backup
/opt/scripts/backup.sh  # On Oracle
/opt/monolith/scripts/backup.sh  # On GCP
```

### n8n Workflow Stuck
```bash
# Check queue
docker exec n8n-redis redis-cli LLEN bull:n8n:workflow:wait

# Restart n8n
docker restart n8n

# Clear stuck executions (careful)
docker exec n8n-postgres psql -U n8n -c "DELETE FROM execution_entity WHERE status = 'running' AND started_at < NOW() - INTERVAL '1 hour';"
```

### Gitea Runner Not Picking Jobs
```bash
# Check runner logs
docker logs gitea-act-runner --tail 50

# Re-register runner
docker exec gitea-act-runner gitea-act-runner register \
  --instance https://gitea.yourdomain.com/ \
  --token <NEW_TOKEN>
```

---

## Maintenance

### Rotate Secrets (Quarterly)
```bash
# 1. Generate new secrets
openssl rand -base64 32  # For DB passwords, admin tokens

# 2. Update in Cloudflare Workers env vars
# 3. Update in docker-compose .env files
# 4. Restart affected services
# 5. Verify backups still work
```

### Update Docker Images (Monthly)
```bash
# On Oracle A1
cd /opt/coolify && docker compose pull && docker compose up -d
cd /opt/n8n && docker compose pull && docker compose up -d
cd /opt/gitea && docker compose pull && docker compose up -d
cd /opt/vaultwarden && docker compose pull && docker compose up -d
cd /opt/jellyfin && docker compose pull && docker compose up -d

# On GCP micro
cd /opt/monolith/uptime-kuma && docker compose pull && docker compose up -d
```

### OpenTofu Version Upgrade
```bash
# Check latest
tofu version

# Upgrade (when new major version)
curl -fsSL https://get.opentofu.org/install.sh | bash

# Test plan
make plan
```

### Prune Docker (Weekly)
```bash
# On Oracle A1 (critical - 50GB boot fills fast)
docker system prune -af --volumes
docker builder prune -af

# On GCP micro
docker system prune -af
```

---

## Disaster Recovery

### Full Oracle A1 Loss
```bash
# 1. Recreate infrastructure
make apply-oci

# 2. Bootstrap new instance
ssh ubuntu@<new-ip> 'bash -s' < scripts/bootstrap-oracle.sh

# 3. Configure rclone
./scripts/setup-rclone.sh

# 4. Restore from R2
rclone sync r2:monolith-ops-backups/oracle-a1 /opt/backups --progress

# 5. Restore databases
gunzip -c /opt/backups/n8n-<latest>.sql.gz | docker exec -i n8n-postgres psql -U n8n n8n
unzip /opt/backups/gitea-<latest>.zip -d /tmp/gitea-restore
# Gitea restore: https://docs.gitea.io/en-us/backup-and-restore/

# 6. Start services
cd /opt/coolify && docker compose up -d
cd /opt/n8n && docker compose up -d
cd /opt/gitea && docker compose up -d
cd /opt/vaultwarden && docker compose up -d
cd /opt/jellyfin && docker compose up -d

# 7. Verify
curl https://n8n.yourdomain.com/healthz
curl https://gitea.yourdomain.com/
```

### Full GCP e2-micro Loss
```bash
# 1. Recreate
make apply-gcp

# 2. New instance auto-boots with startup script
# 3. Wait 5 min for Beszel + Uptime Kuma
# 4. Verify
curl https://status.yourdomain.com/api/health
curl https://beszel.yourdomain.com/api/health
```

### Cloudflare Account Lockout
- Use Cloudflare Dashboard directly
- API tokens scoped per service (Tunnel, DNS, R2, Workers, Access)
- Keep one Global API Key offline for emergency

---

## Capacity Monitoring

### Oracle A1 Limits (Always Free)
| Resource | Limit | Alert Threshold |
|----------|-------|-----------------|
| OCPU Hours | 1,500/mo | 1,200 |
| GB Hours | 9,000/mo | 7,200 |
| Block Storage | 200 GB | 160 GB |
| Egress | 10 TB | 8 TB |

### GCP Limits (Always Free)
| Resource | Limit | Alert Threshold |
|----------|-------|-----------------|
| e2-micro | 1 instance | N/A |
| Cloud Run | 2M req/mo | 1.5M |
| Firestore | 1 GB | 800 MB |
| BigQuery | 1 TB queries | 800 GB |
| Cloud Build | 120 min/day | 90 min |

### Cloudflare Limits (Free)
| Resource | Limit | Alert Threshold |
|----------|-------|-----------------|
| R2 Storage | 10 GB | 8 GB |
| Workers | 100k/day | 80k |
| Zero Trust | 50 seats | 40 |

---

## Contact Escalation

| Issue | Primary | Secondary |
|-------|---------|-----------|
| Oracle billing/suspension | OCI Console → Support (PAYG only) | Twitter @OracleCloud |
| GCP billing | Cloud Console → Billing | Google Cloud Support |
| Cloudflare | Dashboard → Support | Community Discord |
| Tailscale | Admin Console → Support | GitHub Issues |