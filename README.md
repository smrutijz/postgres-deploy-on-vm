# Deploy PostgreSQL on a Google Cloud VM (Free Tier)

This guide helps you deploy PostgreSQL directly (without Docker) on a Google Cloud free-tier VM using the provided `setup.sh` shell script. The script automates the installation and secure configuration of PostgreSQL, sets up a system user, configures the firewall, and enables SSL with Let's Encrypt for secure remote access.

**⚠️ Note:** This setup is intended for personal or small-scale use. It is not production-ready and uses local VM storage only.

---

## 1. Create a Free Tier VM

> **Note:** Google Cloud Free Tier VM types and quotas may change. Always check the [official documentation](https://cloud.google.com/free/docs/free-cloud-features).

- Go to the [Google Cloud Console](https://console.cloud.google.com/).
- Navigate to **Compute Engine → VM Instances → Create Instance**.
- Select the **"E2-micro"** machine type (included in the Free Tier).
- Choose **Ubuntu (latest LTS)** as the OS.
- **Before creating the VM, enable these firewall options:**
  - **HTTP traffic** (port 80)
  - **HTTPS traffic** (port 443)
  - **Allow Load Balancer Health checks**
- **Why?** These rules ensure your server is accessible for web traffic and can be monitored for uptime.

---

## 2. Reserve a Static External IP (Optional)

- After your VM is ready, go to **VPC Network → External IP addresses**.
- Click "Reserve" next to your VM to assign a static IP.
- **Why?** This ensures your server's IP doesn't change, so your DNS always points to the right place.

---

## 3. Update Your DNS

- Go to your domain provider's dashboard.
- Add an **A record** pointing your subdomain (e.g., `pgsql.yourdomain.com`) to your VM's external IP.

---

## 4. Open Firewall Port for PostgreSQL

- In Google Cloud Console, go to **VPC Network → Firewall**.
- Add a rule to allow **TCP connections** from trusted IPs (or `0.0.0.0/0` for open access, not recommended for production) on **port 5432** (PostgreSQL default).
- **Why?** This allows external access to your PostgreSQL instance.

---

## 5. Deploy PostgreSQL

SSH into your VM from the Google Cloud Console and follow these steps:

1. **Install Git (if not already installed):**
   ```bash
   sudo apt update && sudo apt install git -y
   ```

2. **Clone this repository and enter the directory:**
   ```bash
   if [ ! -d "postgres-deploy-on-vm" ]; then
     git clone https://github.com/smrutijz/postgres-deploy-on-vm.git
   fi
   cd postgres-deploy-on-vm
   git pull
   ```

3. **Run the setup script:**
   - **Arguments:**
     1. PostgreSQL database name
     2. PostgreSQL user name
     3. PostgreSQL user password
     4. Your domain name (FQDN)
     5. Your email address (for Let's Encrypt SSL)
   ```bash
   chmod +x ./setup.sh
   sudo ./setup.sh '<pg-database-name>' '<pg-user-name>' '<pg-user-password>' '<your-domain-name>' '<your-email-id>'
   ```

   The script will:
   - Install PostgreSQL and required dependencies
   - Create the specified database and user
   - Configure PostgreSQL to listen on all interfaces (port 5432)
   - Set up SSL certificates for secure connections
   - Adjust the firewall to allow only necessary ports

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

For questions or support, contact **Smruti** at [smrutijz@hotmail.com](mailto:smrutijz@hotmail.com).

Connect on [LinkedIn](https://www.linkedin.com/in/smrutijz/).

You can also chat with my AI bot, **SmrutiRBot**, on Telegram!  
Scan the QR code below to get started:

[![SmrutiRBot](img/smruti-r-bot-telegram-qr-code.png)](https://t.me/SmrutiRBot)
