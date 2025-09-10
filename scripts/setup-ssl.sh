#!/bin/bash

# SSL Setup Script for Let's Encrypt
# This script sets up SSL certificates using Let's Encrypt

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${YELLOW}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get domain name from user
read -p "Enter your domain name (e.g., yourdomain.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    print_error "Domain name is required"
    exit 1
fi

read -p "Enter www subdomain? (y/n): " INCLUDE_WWW

APP_DIR="/home/deployer/gifs-landing-page"
SSL_DIR="$APP_DIR/ssl"

print_status "Setting up SSL for domain: $DOMAIN"

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    print_status "Installing certbot..."
    apt update
    apt install snapd -y
    snap install core; snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    print_success "Certbot installed"
fi

# Stop nginx if running to free up port 80
print_status "Stopping nginx temporarily..."
if docker ps | grep -q nginx; then
    cd "$APP_DIR"
    docker-compose -f docker-compose.prod.yml stop nginx
fi

# Generate SSL certificate
print_status "Generating SSL certificate..."
if [ "$INCLUDE_WWW" = "y" ] || [ "$INCLUDE_WWW" = "Y" ]; then
    certbot certonly --standalone -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email
else
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email
fi

# Create SSL directory
mkdir -p "$SSL_DIR"

# Copy certificates
print_status "Copying certificates to application directory..."
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"

# Generate DH parameters for additional security
print_status "Generating DH parameters (this may take a while)..."
openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048

# Set proper ownership
chown -R deployer:deployer "$SSL_DIR"
chmod 644 "$SSL_DIR/cert.pem"
chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/dhparam.pem"

print_success "SSL certificates configured"

# Update nginx configuration for the domain
print_status "Updating nginx configuration..."
sed -i "s/server_name _;/server_name $DOMAIN www.$DOMAIN;/g" "$APP_DIR/nginx.prod.conf"

# Restart containers with SSL
print_status "Starting containers with SSL..."
cd "$APP_DIR"
docker-compose -f docker-compose.prod.yml up -d
print_success "Containers restarted with SSL"

# Set up automatic renewal
print_status "Setting up automatic certificate renewal..."
cat > /etc/cron.d/certbot-renew << EOF
# Renew Let's Encrypt certificates
0 12 * * * root /usr/bin/certbot renew --quiet --deploy-hook "cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $SSL_DIR/cert.pem && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $SSL_DIR/key.pem && chown deployer:deployer $SSL_DIR/*.pem && cd $APP_DIR && docker-compose -f docker-compose.prod.yml restart nginx"
EOF

print_success "Automatic renewal configured"

# Test SSL configuration
sleep 10
print_status "Testing SSL configuration..."
if curl -f -s https://"$DOMAIN"/api/health > /dev/null 2>&1; then
    print_success "SSL is working correctly!"
else
    print_error "SSL test failed. Check the logs:"
    cd "$APP_DIR"
    docker-compose -f docker-compose.prod.yml logs nginx
fi

print_success "🔒 SSL setup completed successfully!"
echo ""
echo -e "${GREEN}Your site is now accessible at:${NC}"
echo "  • HTTPS: https://$DOMAIN"
if [ "$INCLUDE_WWW" = "y" ] || [ "$INCLUDE_WWW" = "Y" ]; then
    echo "  • HTTPS: https://www.$DOMAIN"
fi
echo ""
echo -e "${YELLOW}Certificate will auto-renew. Check status with:${NC}"
echo "  • sudo certbot certificates"
echo "  • sudo certbot renew --dry-run"