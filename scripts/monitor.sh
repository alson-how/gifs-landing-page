#!/bin/bash

# System Monitoring Script
# This script monitors the application and system resources

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_DIR="/home/deployer/gifs-landing-page"

# Function to print headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_status() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Clear screen and show header
clear
echo -e "${BLUE}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║        GIFS Landing Page Monitor      ║"
echo "  ║             $(date '+%Y-%m-%d %H:%M:%S')           ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# System Information
print_header "SYSTEM INFORMATION"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3 " / " $2 " (" int($3/$2 * 100.0) "%)"}')"
echo "Disk Usage: $(df -h / | tail -1 | awk '{print $3 " / " $2 " (" $5 ")"}')"

# Docker Status
print_header "DOCKER STATUS"
if command -v docker &> /dev/null && docker info &> /dev/null; then
    print_success "Docker is running"
    echo "Docker Version: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    echo "Docker Compose Version: $(docker-compose --version | cut -d' ' -f3 | tr -d ',')"
else
    print_error "Docker is not running or not accessible"
fi

# Container Status
print_header "CONTAINER STATUS"
if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR"
    if [ -f "docker-compose.prod.yml" ]; then
        echo "Container Status:"
        docker-compose -f docker-compose.prod.yml ps
        
        echo -e "\nContainer Resource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker-compose -f docker-compose.prod.yml ps -q) 2>/dev/null || echo "No containers running"
    else
        print_error "docker-compose.prod.yml not found"
    fi
else
    print_error "Application directory not found: $APP_DIR"
fi

# Application Health
print_header "APPLICATION HEALTH"
if curl -f -s http://localhost:3000/api/health > /dev/null 2>&1; then
    print_success "Application health check passed"
    HEALTH_DATA=$(curl -s http://localhost:3000/api/health)
    echo "Health Status: $HEALTH_DATA"
else
    print_error "Application health check failed"
fi

# Database Status
print_header "DATABASE STATUS"
DB_PATH="$APP_DIR/data/database.db"
if [ -f "$DB_PATH" ]; then
    print_success "Database file exists"
    echo "Database Size: $(du -h "$DB_PATH" | cut -f1)"
    echo "Last Modified: $(stat -c %y "$DB_PATH" | cut -d'.' -f1)"
    
    # Count records if sqlite3 is available
    if command -v sqlite3 &> /dev/null; then
        CONTACT_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM contacts;" 2>/dev/null || echo "N/A")
        EMAIL_LOG_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM email_logs;" 2>/dev/null || echo "N/A")
        echo "Contact Records: $CONTACT_COUNT"
        echo "Email Log Records: $EMAIL_LOG_COUNT"
    fi
else
    print_error "Database file not found"
fi

# Recent Logs
print_header "RECENT APPLICATION LOGS (Last 10 lines)"
if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR"
    if docker-compose -f docker-compose.prod.yml ps logistics-app &> /dev/null; then
        docker-compose -f docker-compose.prod.yml logs --tail=10 logistics-app 2>/dev/null || echo "No logs available"
    else
        echo "Application container not running"
    fi
fi

# Nginx Status
print_header "NGINX STATUS"
if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR"
    if docker-compose -f docker-compose.prod.yml ps nginx &> /dev/null; then
        print_success "Nginx container is running"
        
        # Check SSL certificates if they exist
        SSL_DIR="$APP_DIR/ssl"
        if [ -f "$SSL_DIR/cert.pem" ]; then
            print_success "SSL certificate found"
            CERT_EXPIRY=$(openssl x509 -in "$SSL_DIR/cert.pem" -noout -dates | grep notAfter | cut -d= -f2)
            echo "Certificate Expires: $CERT_EXPIRY"
        else
            print_status "No SSL certificate found"
        fi
    else
        print_error "Nginx container not running"
    fi
fi

# Network Connectivity
print_header "NETWORK CONNECTIVITY"
if ping -c 1 8.8.8.8 &> /dev/null; then
    print_success "Internet connectivity: OK"
else
    print_error "Internet connectivity: FAILED"
fi

# Port Status
print_header "PORT STATUS"
echo "Listening Ports:"
netstat -tlnp 2>/dev/null | grep -E ':80|:443|:3000' | head -5

# Backup Status
print_header "BACKUP STATUS"
BACKUP_DIR="/home/deployer/backups"
if [ -d "$BACKUP_DIR" ]; then
    BACKUP_COUNT=$(ls "$BACKUP_DIR"/database_backup_*.db.gz 2>/dev/null | wc -l)
    if [ $BACKUP_COUNT -gt 0 ]; then
        print_success "$BACKUP_COUNT backups available"
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/database_backup_*.db.gz 2>/dev/null | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            echo "Latest Backup: $(basename "$LATEST_BACKUP")"
            echo "Backup Size: $(du -h "$LATEST_BACKUP" | cut -f1)"
            echo "Backup Age: $(stat -c %y "$LATEST_BACKUP" | cut -d'.' -f1)"
        fi
    else
        print_error "No backups found"
    fi
else
    print_error "Backup directory not found"
fi

# System Alerts
print_header "SYSTEM ALERTS"
ALERTS=()

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print int($5)}')
if [ $DISK_USAGE -gt 80 ]; then
    ALERTS+=("High disk usage: ${DISK_USAGE}%")
fi

# Check memory usage
MEM_USAGE=$(free | grep '^Mem:' | awk '{print int($3/$2 * 100.0)}')
if [ $MEM_USAGE -gt 80 ]; then
    ALERTS+=("High memory usage: ${MEM_USAGE}%")
fi

# Check load average
LOAD_AVG=$(cat /proc/loadavg | cut -d' ' -f1)
if (( $(echo "$LOAD_AVG > 2.0" | bc -l) )); then
    ALERTS+=("High load average: $LOAD_AVG")
fi

if [ ${#ALERTS[@]} -eq 0 ]; then
    print_success "No system alerts"
else
    for alert in "${ALERTS[@]}"; do
        print_error "$alert"
    done
fi

echo -e "\n${BLUE}Monitoring completed at $(date)${NC}"
echo -e "${YELLOW}Run this script periodically or set up automated monitoring${NC}"