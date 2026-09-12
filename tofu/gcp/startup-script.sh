#!/bin/bash
set -euo pipefail

# GCP e2-micro startup script
# Installs: docker, docker-compose, tofu, rclone, beszel-agent, uptime-kuma (via docker), cron jobs

export DEBIAN_FRONTEND=noninteractive
apt-get update
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
  python3 \
  python3-pip \
  rclone

# Install OpenTofu
curl -fsSL https://get.opentofu.org/install.sh | bash

# Install Beszel agent
curl -fsSL https://beszel.com/install.sh | bash -s -- --agent

# Configure Docker
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

# Configure UFW
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow from 100.64.0.0/10 to any port 41641 proto udp comment 'Tailscale'
ufw allow from ${admin_cidr} to any port 22 proto tcp comment 'Admin SSH'

# Configure fail2ban
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

# Configure chrony
systemctl enable chrony
systemctl start chrony

# Create directories
mkdir -p /opt/monolith/{backups,scripts,beszel,uptime-kuma}
chown -R ubuntu:ubuntu /opt/monolith

# Deploy Beszel agent (runs as systemd service via installer)
# Deploy Uptime Kuma via docker-compose
cat > /opt/monolith/uptime-kuma/docker-compose.yaml <<'EOF'
version: '3.8'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    volumes:
      - ./data:/app/data
    ports:
      - "3001:3001"
    restart: unless-stopped
    networks:
      - monolith
networks:
  monolith:
    external: true
EOF

# Create docker network
docker network create monolith || true

# Start Uptime Kuma
cd /opt/monolith/uptime-kuma && docker compose up -d

# Create backup script
cat > /opt/monolith/scripts/backup.sh <<'BACKUP_EOF'
#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/opt/monolith/backups"

# Backup Oracle DB via SSH (requires SSH key)
# ssh ubuntu@$${ORACLE_IP} "docker exec n8n-postgres pg_dump -U n8n n8n" | gzip > $${BACKUP_DIR}/n8n-$${DATE}.sql.gz

# Backup Gitea
# ssh ubuntu@$${ORACLE_IP} "docker exec gitea gitea dump -c /data/gitea/conf/app.ini" > $${BACKUP_DIR}/gitea-$${DATE}.zip

# Sync to R2
rclone sync $${BACKUP_DIR} r2:monolith-ops-backups/gcp-watchdog --progress

# Cleanup old backups (keep 7 days)
find $${BACKUP_DIR} -type f -mtime +7 -delete
BACKUP_EOF

chmod +x /opt/monolith/scripts/backup.sh
chown -R ubuntu:ubuntu /opt/monolith/scripts

# Create systemd timer for nightly backup
cat > /etc/systemd/system/monolith-backup.service <<'EOF'
[Unit]
Description=Monolith nightly backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=ubuntu
ExecStart=/opt/monolith/scripts/backup.sh
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

# Create plan timer (every 6 hours)
cat > /opt/monolith/scripts/plan.sh <<'PLAN_EOF'
#!/bin/bash
set -euo pipefail

cd /home/ubuntu/monolith-ops
git pull origin main
make plan 2>&1 | tee /opt/monolith/backups/plan-$(date +%Y%m%d-%H%M%S).log
PLAN_EOF

chmod +x /opt/monolith/scripts/plan.sh

cat > /etc/systemd/system/monolith-plan.service <<'EOF'
[Unit]
Description=Monolith infrastructure plan
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=ubuntu
ExecStart=/opt/monolith/scripts/plan.sh
EOF

cat > /etc/systemd/system/monolith-plan.timer <<'EOF'
[Unit]
Description=Run monolith-plan every 6 hours

[Timer]
OnCalendar=*:0/6
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable monolith-plan.timer
systemctl start monolith-plan.timer

echo "GCP e2-micro bootstrap complete. Beszel agent, Uptime Kuma, backup & plan timers active."