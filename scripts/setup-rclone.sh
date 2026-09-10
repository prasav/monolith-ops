#!/bin/bash
set -euo pipefail

# rclone setup for R2 backups
# Run on both Oracle A1 and GCP e2-micro

echo "=== Configuring rclone for Cloudflare R2 ==="

# Check if config exists
if [ -f ~/.config/rclone/rclone.conf ]; then
    echo "rclone config already exists"
    exit 0
fi

mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf <<'EOF'
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = https://${CLOUDFLARE_ACCOUNT_ID}.r2.cloudflarestorage.com
acl = private
region = auto
no_check_bucket = true
EOF

echo "rclone config template created at ~/.config/rclone/rclone.conf"
echo "Edit it with your R2 credentials:"
echo "  R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY from Cloudflare R2 API Tokens"
echo "  CLOUDFLARE_ACCOUNT_ID from Cloudflare dashboard"
echo ""
echo "Test with: rclone lsd r2:"