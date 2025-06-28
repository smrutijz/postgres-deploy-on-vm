#!/bin/bash
set -euo pipefail

# ────────────────────────────────
# 📥 Inputs
# ────────────────────────────────
DB_NAME=${1:? "Database name required"}
DB_USER=${2:? "Database user required"}
DB_PASS=${3:? "Database password required"}
DOMAIN=${4:? "Your domain (FQDN) name required"}
EMAIL=${5:? "Your email (for Let's Encrypt) required"}

# ────────────────────────────────
echo "📦 Installing PostgreSQL, Certbot, and tools..."
apt update -y
apt install -y postgresql curl certbot

# ────────────────────────────────
# 📍 Configure PostgreSQL for remote SSL
# ────────────────────────────────
PG_VERSION=$(ls /etc/postgresql)
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
PG_MAIN="/etc/postgresql/$PG_VERSION/main"

echo "🔧 Configuring PostgreSQL to allow remote SSL access..."

# Listen on all interfaces
sed -i "s/^#*listen_addresses = .*/listen_addresses = '*'/" "$PG_CONF"

# Add hostssl line if not already present
if ! grep -q "^hostssl all all 0.0.0.0/0 scram-sha-256" "$PG_HBA"; then
    echo "hostssl all all 0.0.0.0/0 scram-sha-256" >> "$PG_HBA"
fi

systemctl restart postgresql

# ────────────────────────────────
# 🛠️ Create or update DB user and database
# ────────────────────────────────

echo "🔨 Creating or updating database user and database..."

sudo -u postgres psql <<EOF
DO
\$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';
    ELSE
        ALTER ROLE $DB_USER WITH PASSWORD '$DB_PASS';
    END IF;
END
\$\$;
CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOF

# ────────────────────────────────
# 🔒 Obtain SSL certificate from Let's Encrypt
# ────────────────────────────────
echo "🔐 Getting Let's Encrypt SSL certificate for $DOMAIN..."

# Stop any services blocking port 80 (e.g., nginx)
if systemctl is-active --quiet nginx; then
    systemctl stop nginx
fi

certbot certonly --standalone --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN"

# Restart nginx if it was running
if systemctl list-units --type=service | grep -q nginx; then
    systemctl start nginx
fi

# ────────────────────────────────
# Install SSL certs for PostgreSQL
# ────────────────────────────────
echo "📂 Installing SSL certificates..."

cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$PG_MAIN/server.crt"
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem "$PG_MAIN/server.key"
chmod 600 "$PG_MAIN/server.key"
chown postgres:postgres "$PG_MAIN/server.crt" "$PG_MAIN/server.key"

# Enable SSL in config (only once)
if ! grep -q "^ssl = on" "$PG_CONF"; then
    echo "ssl = on" >> "$PG_CONF"
fi
if ! grep -q "^ssl_cert_file = 'server.crt'" "$PG_CONF"; then
    echo "ssl_cert_file = 'server.crt'" >> "$PG_CONF"
fi
if ! grep -q "^ssl_key_file = 'server.key'" "$PG_CONF"; then
    echo "ssl_key_file = 'server.key'" >> "$PG_CONF"
fi

systemctl restart postgresql

# ────────────────────────────────
# ✅ Done
# ────────────────────────────────
echo "✅ PostgreSQL is installed and running with SSL."
echo "🌍 Connect remotely using:"
echo "    psql \"sslmode=require host=$DOMAIN dbname=$DB_NAME user=$DB_USER\""
