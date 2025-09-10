# DigitalOcean Deployment Guide

Complete guide to deploy your Node.js Email Application to DigitalOcean from scratch.

## Prerequisites

- DigitalOcean account
- Domain name (optional but recommended)
- EmailJS account with configured service and template
- SSH key pair

## Step 1: Create DigitalOcean Droplet

### 1.1 Create Droplet
```bash
# Via DigitalOcean Dashboard:
# 1. Click "Create" → "Droplets"
# 2. Choose Ubuntu 22.04 LTS
# 3. Select plan: Basic ($6/month minimum recommended)
# 4. Choose datacenter region (closest to your users)
# 5. Add your SSH key
# 6. Choose hostname: gifs-landing-page
# 7. Click "Create Droplet"
```

### 1.2 Domain Setup (Optional)
```bash
# In DigitalOcean Dashboard:
# 1. Go to "Networking" → "Domains"
# 2. Add your domain
# 3. Create A record pointing to your droplet IP
# 4. Create CNAME for www pointing to your domain
```

## Step 2: Initial Server Setup

### 2.1 Connect to Server
```bash
# Replace YOUR_DROPLET_IP with actual IP
ssh root@YOUR_DROPLET_IP
```

### 2.2 Create Non-Root User
```bash
# Create new user
adduser deployer
usermod -aG sudo deployer

# Copy SSH keys to new user
rsync --archive --chown=deployer:deployer ~/.ssh /home/deployer
```

### 2.3 Configure Firewall
```bash
# Enable UFW firewall
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Check status
ufw status
```

### 2.4 Update System
```bash
apt update && apt upgrade -y
```

## Step 3: Install Docker

### 3.1 Install Docker
```bash
# Install dependencies
apt install apt-transport-https ca-certificates curl software-properties-common -y

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt update
apt install docker-ce docker-ce-cli containerd.io -y

# Add user to docker group
usermod -aG docker deployer
```

### 3.2 Install Docker Compose
```bash
# Download Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Make executable
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

## Step 4: Deploy Application

### 4.1 Switch to Deployer User
```bash
su - deployer
```

### 4.2 Clone Repository
```bash
# Clone your repository
git clone https://github.com/alson-how/gifs-landing-page.git
cd gifs-landing-page
```

### 4.3 Configure Environment
```bash
# Copy environment file
cp .env.example .env

# Edit with your actual credentials
nano .env
```

**Configure these variables in .env:**
```env
# EmailJS Configuration (get from https://www.emailjs.com/)
EMAILJS_SERVICE_ID=your_actual_service_id
EMAILJS_TEMPLATE_ID=your_actual_template_id
EMAILJS_PUBLIC_KEY=your_actual_public_key
EMAILJS_PRIVATE_KEY=your_actual_private_key

# Email Configuration
TO_EMAIL=your-email@domain.com

# Server Configuration
PORT=3000
NODE_ENV=production

# Database Configuration
DB_PATH=/usr/src/app/data/database.db
```

### 4.4 Create Production Directories
```bash
# Create required directories
mkdir -p data ssl logs
chmod 755 data ssl logs
```

## Step 5: SSL Certificate (Let's Encrypt)

### 5.1 Install Certbot
```bash
sudo apt install snapd -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

### 5.2 Obtain SSL Certificate
```bash
# Replace your-domain.com with your actual domain
sudo certbot certonly --standalone -d your-domain.com -d www.your-domain.com

# Copy certificates to project
sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem ~/gifs-landing-page/ssl/cert.pem
sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem ~/gifs-landing-page/ssl/key.pem
sudo chown deployer:deployer ~/gifs-landing-page/ssl/*.pem
```

### 5.3 Setup Auto-Renewal
```bash
# Add to crontab
sudo crontab -e

# Add this line for automatic renewal
0 12 * * * /usr/bin/certbot renew --quiet && docker-compose -f /home/deployer/gifs-landing-page/docker-compose.prod.yml restart nginx
```

## Step 6: Deploy with Docker

### 6.1 Build and Start Services
```bash
# Build and start production services
docker-compose -f docker-compose.prod.yml up -d --build

# Check status
docker-compose -f docker-compose.prod.yml ps
```

### 6.2 View Logs
```bash
# View application logs
docker-compose -f docker-compose.prod.yml logs -f logistics-app

# View nginx logs
docker-compose -f docker-compose.prod.yml logs -f nginx
```

## Step 7: Monitoring and Maintenance

### 7.1 Health Check
```bash
# Check application health
curl http://localhost:3000/api/health

# Check via domain (if configured)
curl https://your-domain.com/api/health
```

### 7.2 Database Backup Script
```bash
# Create backup directory
mkdir -p ~/backups

# Create backup script
cat > ~/backup_db.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/deployer/backups"
DB_PATH="/home/deployer/gifs-landing-page/data/database.db"

# Create backup
cp "$DB_PATH" "$BACKUP_DIR/database_backup_$DATE.db"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "database_backup_*.db" -mtime +7 -delete

echo "Database backup completed: database_backup_$DATE.db"
EOF

# Make executable
chmod +x ~/backup_db.sh

# Add to crontab for daily backups at 2 AM
crontab -e
# Add: 0 2 * * * /home/deployer/backup_db.sh
```

### 7.3 Update Application
```bash
# Pull latest changes
git pull origin master

# Rebuild and restart
docker-compose -f docker-compose.prod.yml up -d --build

# Clean up old images
docker image prune -f
```

### 7.4 System Monitoring
```bash
# Check system resources
htop
df -h
docker stats

# Check application status
docker-compose -f docker-compose.prod.yml ps
```

## Step 8: Security Best Practices

### 8.1 Fail2Ban (Optional)
```bash
# Install fail2ban for SSH protection
sudo apt install fail2ban -y

# Configure fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 8.2 Regular Updates
```bash
# Create update script
cat > ~/update_system.sh << 'EOF'
#!/bin/bash
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo snap refresh
docker system prune -f
EOF

chmod +x ~/update_system.sh

# Schedule weekly updates (Sundays at 3 AM)
# Add to crontab: 0 3 * * 0 /home/deployer/update_system.sh
```

## Troubleshooting

### Common Issues

1. **Docker permission denied**
   ```bash
   sudo usermod -aG docker $USER
   # Then logout and login again
   ```

2. **Port 80/443 already in use**
   ```bash
   sudo netstat -tlnp | grep :80
   sudo systemctl stop apache2  # if Apache is running
   ```

3. **SSL certificate issues**
   ```bash
   sudo certbot certificates
   sudo certbot renew --dry-run
   ```

4. **Application not accessible**
   ```bash
   # Check UFW firewall
   sudo ufw status
   
   # Check Docker containers
   docker-compose -f docker-compose.prod.yml logs
   ```

5. **Database connection issues**
   ```bash
   # Check data directory permissions
   ls -la data/
   # Check container logs
   docker-compose -f docker-compose.prod.yml logs logistics-app
   ```

## Performance Optimization

### 8.1 Enable Docker Logging
```bash
# Add to docker-compose.prod.yml logging configuration:
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 8.2 Monitoring with htop
```bash
sudo apt install htop -y
```

Your application should now be successfully deployed and accessible at your domain or server IP!

## Quick Commands Reference

```bash
# Deploy/Update
git pull && docker-compose -f docker-compose.prod.yml up -d --build

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart services
docker-compose -f docker-compose.prod.yml restart

# Stop services
docker-compose -f docker-compose.prod.yml down

# Database backup
./backup_db.sh

# System update
./update_system.sh
```