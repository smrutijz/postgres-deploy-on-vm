#!/bin/bash
set -euo pipefail

# ────────────────────────────────
# 📥 Inputs
# ────────────────────────────────
DB_NAME=${1:? "Database name required"}
DB_USER=${2:? "Database user required"}
DB_PASS=${3:? "Database password required"}
DOMAIN=${4:? "Your domain (FQDN) name required"}
EMAIL=${5:? "Your email (for Let us Encrypt) required"}

# ────────────────────────────────
echo "📦 Installing PostgreSQL, Certbot, and tools..."
apt update -y
apt install -y postgresql curl certbot

# ────────────────────────────────
# 📍 Configure PostgreSQL
# ────────────────────────────────
PG_VERSION=$(ls /etc/postgresql)
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
PG_MAIN="/etc/postgresql/$PG_VERSION/main"

echo "🔧 Configuring PostgreSQL to allow remote SSL access..."

sed -i "s/^#*listen_addresses = .*/listen_addresses = '*'/" "$PG_CONF"
echo "hostssl all all 0.0.0.0/0 scram-sha-256" >> "$PG_HBA"

systemctl restart postgresql

# ────────────────────────────────
# 🛠️ Create DB and user
# ────────────────────────────────
sudo -u postgres psql <<EOF
CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
ALTER USER $DB_USER SET password_encryption = 'scram-sha-256';
EOF

# ────────────────────────────────
# 🔒 Obtain SSL Cert for db.smrutiaisolution.fun
# ────────────────────────────────
echo "🔐 Getting Let's Encrypt SSL certificate for $DOMAIN..."
certbot certonly --standalone --non-interactive --agree-tos --register-unsafely-without-email \
  -m "$EMAIL" -d "$DOMAIN"

# Copy SSL certs into PostgreSQL folder
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$PG_MAIN/server.crt"
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem "$PG_MAIN/server.key"
chmod 600 "$PG_MAIN/server.key"
chown postgres:postgres "$PG_MAIN/server.crt" "$PG_MAIN/server.key"

# Enable SSL in PostgreSQL config
echo "ssl = on" >> "$PG_CONF"
echo "ssl_cert_file = 'server.crt'" >> "$PG_CONF"
echo "ssl_key_file = 'server.key'" >> "$PG_CONF"

systemctl restart postgresql

# ────────────────────────────────
# ✅ Finish
# ────────────────────────────────
echo "✅ PostgreSQL is installed and running with SSL."
echo "🌍 Connect remotely using:"
echo "    psql \"sslmode=require host=$DOMAIN dbname=$DB_NAME user=$DB_USER\""
