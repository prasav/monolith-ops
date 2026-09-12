#!/bin/bash
set -euo pipefail

# Bootstrap script for Oracle A1 instance
# Run once after instance is up: ssh ubuntu@<IP> 'bash -s' < bootstrap-oracle.sh

export DEBIAN_FRONTEND=noninteractive

echo "=== Updating system ==="
apt-get update && apt-get upgrade -y

echo "=== Installing base packages ==="
apt-get install -y \
  docker.io \
  docker-compose-v2 \
  git \
  curl \
  wget \
  unzip \
  jq \
  htop \
  ncdu \
  ufw \
  fail2ban \
  chrony \
  ca-certificates \
  gnupg \
  lsb-release \
  rclone \
  wireguard

# Tailscale (official repo — not in Ubuntu archives)
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh || echo "WARNING: tailscale install failed, continuing without it"
fi

echo "=== Installing OpenTofu (optional on app server) ==="
curl -fsSL https://get.opentofu.org/install.sh | bash || echo "WARNING: opentofu install failed, continuing without it"

echo "=== Configuring Docker ==="
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "=== Configuring UFW ==="
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
# SSH from admin only (will be restricted by OCI NSG too)
# ufw allow from <ADMIN_CIDR> to any port 22 proto tcp
# Tailscale
ufw allow from 100.64.0.0/10 to any port 41641 proto udp comment 'Tailscale'

echo "=== Configuring fail2ban ==="
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
systemctl enable fail2ban
systemctl start fail2ban

echo "=== Configuring chrony ==="
systemctl enable chrony
systemctl start chrony

echo "=== Setting up Tailscale ==="
# Run: tailscale up --authkey=<KEY> --advertise-routes=10.0.0.0/16 --advertise-exit-node
# Then approve in Tailscale admin console

echo "=== Creating directories ==="
mkdir -p /opt/{coolify,n8n,gitea,vaultwarden,jellyfin,backups,scripts}
chown -R ubuntu:ubuntu /opt/coolify /opt/n8n /opt/gitea /opt/vaultwarden /opt/jellyfin /opt/backups /opt/scripts
# NOTE: this image uses opc (uid 1000) for container volumes; n8n data dir must
# be writable by uid 1000 and N8N_ENCRYPTION_KEY must be set (see runbook).
mkdir -p /opt/n8n/data && chown 1000:1000 /opt/n8n/data && chmod 775 /opt/n8n/data

echo "=== Creating docker networks ==="
docker network create monolith || true
docker network create coolify || true

echo "=== Installing Coolify (official installer: postgres+redis+soketi) ==="
cd /opt/coolify
curl -fsSL https://cdn.coollabs.io/coolify/install.sh -o install.sh
bash install.sh || echo "WARNING: coolify install failed, check /data/coolify/source/*.log"
cd -

echo "=== Creating n8n docker-compose ==="
cat > /opt/n8n/docker-compose.yaml <<'EOF'
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    volumes:
      - ./data:/home/node/.n8n
    ports:
      - "5678:5678"
    restart: unless-stopped
    environment:
      - N8N_HOST=n8n.${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.${DOMAIN}/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${N8N_DB_PASSWORD}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
    depends_on:
      - postgres
      - redis
    networks:
      - monolith

  postgres:
    image: postgres:16-alpine
    container_name: n8n-postgres
    volumes:
      - ./postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${N8N_DB_PASSWORD}
    networks:
      - monolith
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: n8n-redis
    volumes:
      - ./redis:/data
    networks:
      - monolith
    restart: unless-stopped

networks:
  monolith:
    external: true
EOF

echo "=== Creating Gitea docker-compose ==="
cat > /opt/gitea/docker-compose.yaml <<'EOF'
version: '3.8'
services:
  gitea:
    image: gitea/gitea:1.22-rootless
    container_name: gitea
    volumes:
      - ./data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
    restart: unless-stopped
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=postgres:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${GITEA_DB_PASSWORD}
      - GITEA__server__DOMAIN=gitea.${DOMAIN}
      - GITEA__server__ROOT_URL=https://gitea.${DOMAIN}/
      - GITEA__server__SSH_DOMAIN=gitea.${DOMAIN}
      - GITEA__server__SSH_PORT=222
    depends_on:
      - postgres
    networks:
      - monolith

  postgres:
    image: postgres:16-alpine
    container_name: gitea-postgres
    volumes:
      - ./postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=gitea
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=${GITEA_DB_PASSWORD}
    networks:
      - monolith
    restart: unless-stopped

  gitea-act-runner:
    image: gitea/act_runner:latest
    container_name: gitea-act-runner
    volumes:
      - ./act_runner:/data
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - GITEA_INSTANCE_URL=https://gitea.${DOMAIN}/
      - GITEA_RUNNER_REGISTRATION_TOKEN=${GITEA_RUNNER_TOKEN}
    networks:
      - monolith
    restart: unless-stopped

networks:
  monolith:
    external: true
EOF

echo "=== Creating Vaultwarden docker-compose ==="
cat > /opt/vaultwarden/docker-compose.yaml <<'EOF'
version: '3.8'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    volumes:
      - ./data:/data
    ports:
      - "8080:80"
    restart: unless-stopped
    environment:
      - SIGNUPS_ALLOWED=false
      - INVITATIONS_ALLOWED=true
      - ADMIN_TOKEN=${VAULTWARDEN_ADMIN_TOKEN}
      - DOMAIN=https://vaultwarden.${DOMAIN}
    networks:
      - monolith
networks:
  monolith:
    external: true
EOF

echo "=== Creating Jellyfin docker-compose (Direct Play only) ==="
cat > /opt/jellyfin/docker-compose.yaml <<'EOF'
version: '3.8'
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    volumes:
      - ./config:/config
      - ./cache:/cache
      - /mnt/media:/media  # Mount from rclone or separate volume
    ports:
      - "8096:8096"
    restart: unless-stopped
    environment:
      - TZ=Asia/Kolkata
    networks:
      - monolith
    # No hardware transcoding on ARM - Direct Play only
networks:
  monolith:
    external: true
EOF

echo "=== Creating backup script ==="
cat > /opt/scripts/backup.sh <<'BACKUP_EOF'
#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/opt/backups"

# n8n Postgres backup
docker exec n8n-postgres pg_dump -U n8n n8n | gzip > ${BACKUP_DIR}/n8n-${DATE}.sql.gz

# Gitea backup
docker exec gitea gitea dump -c /data/gitea/conf/app.ini --temp-path /tmp > ${BACKUP_DIR}/gitea-${DATE}.zip 2>/dev/null || true

# Vaultwarden backup (sqlite)
cp /opt/vaultwarden/data/db.sqlite3 ${BACKUP_DIR}/vaultwarden-${DATE}.sqlite3

# Coolify backup
docker exec coolify coolify backup --destination /data/backups/coolify-${DATE}.tar.gz 2>/dev/null || true
cp /opt/coolify/data/backups/coolify-${DATE}.tar.gz ${BACKUP_DIR}/ 2>/dev/null || true

# Sync to R2
rclone sync ${BACKUP_DIR} r2:monolith-ops-backups/oracle-a1 --progress

# Cleanup old backups (keep 7 days local, 30 days R2)
find ${BACKUP_DIR} -type f -mtime +7 -delete

echo "Backup complete: ${DATE}"
BACKUP_EOF

chmod +x /opt/scripts/backup.sh
chown -R ubuntu:ubuntu /opt/scripts

echo "=== Creating systemd backup timer ==="
cat > /etc/systemd/system/monolith-backup.service <<'EOF'
[Unit]
Description=Monolith nightly backup (Oracle)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=ubuntu
ExecStart=/opt/scripts/backup.sh
EOF

cat > /etc/systemd/system/monolith-backup.timer <<'EOF'
[Unit]
Description=Run monolith-backup daily at 02:00

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable monolith-backup.timer
systemctl start monolith-backup.timer

echo "=== Creating rclone config template ==="
mkdir -p /home/ubuntu/.config/rclone
cat > /home/ubuntu/.config/rclone/rclone.conf.template <<'EOF'
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com
acl = private
EOF

chown ubuntu:ubuntu /home/ubuntu/.config/rclone/rclone.conf.template

echo "=== Oracle A1 bootstrap complete ==="
echo ""
echo "Next steps:"
echo "1. Configure rclone: cp ~/.config/rclone/rclone.conf.template ~/.config/rclone/rclone.conf && edit"
echo "2. Start Tailscale: tailscale up --authkey=<KEY> --advertise-routes=10.0.0.0/16 --advertise-exit-node"
echo "3. Configure Cloudflare Tunnel: cloudflared tunnel login; cloudflared tunnel run --token <TOKEN> oracle-a1"
echo "4. Set env vars in /opt/*/docker-compose.yaml or create .env files"
echo "5. Start services: cd /opt/coolify && docker compose up -d (repeat for n8n, gitea, vaultwarden, jellyfin)"
echo "6. Configure Zero Trust Access in Cloudflare dashboard"