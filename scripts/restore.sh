#!/bin/bash

# Database Restore Script
# This script restores a database from backup

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/home/deployer/gifs-landing-page"
BACKUP_DIR="/home/deployer/backups"
DB_PATH="$APP_DIR/data/database.db"

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

# Check if running as deployer user
if [ "$USER" != "deployer" ]; then
    print_error "This script should be run as the 'deployer' user"
    exit 1
fi

echo ""
print_status "Available backups:"
if ls "$BACKUP_DIR"/database_backup_*.db.gz > /dev/null 2>&1; then
    ls -lah "$BACKUP_DIR"/database_backup_*.db.gz | nl
else
    print_error "No backups found in $BACKUP_DIR"
    exit 1
fi

echo ""
read -p "Enter the backup filename (or number from list above): " BACKUP_INPUT

# Check if input is a number
if [[ "$BACKUP_INPUT" =~ ^[0-9]+$ ]]; then
    # User entered a number, get the corresponding file
    BACKUP_FILE=$(ls "$BACKUP_DIR"/database_backup_*.db.gz | sed -n "${BACKUP_INPUT}p")
    if [ -z "$BACKUP_FILE" ]; then
        print_error "Invalid backup number"
        exit 1
    fi
else
    # User entered a filename
    if [[ "$BACKUP_INPUT" != *.db.gz ]]; then
        BACKUP_INPUT="$BACKUP_INPUT.db.gz"
    fi
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_INPUT"
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

print_status "Selected backup: $(basename $BACKUP_FILE)"

# Confirmation
echo ""
echo -e "${RED}⚠️  WARNING: This will replace the current database!${NC}"
echo "Current database will be backed up before restoration."
echo ""
read -p "Are you sure you want to continue? (y/N): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Restoration cancelled."
    exit 0
fi

# Backup current database
if [ -f "$DB_PATH" ]; then
    print_status "Backing up current database..."
    CURRENT_BACKUP="$BACKUP_DIR/database_backup_before_restore_$(date +%Y%m%d_%H%M%S).db.gz"
    gzip -c "$DB_PATH" > "$CURRENT_BACKUP"
    print_success "Current database backed up to: $(basename $CURRENT_BACKUP)"
fi

# Stop the application
print_status "Stopping application..."
cd "$APP_DIR"
docker-compose -f docker-compose.prod.yml stop logistics-app

# Restore database
print_status "Restoring database from backup..."
gunzip -c "$BACKUP_FILE" > "$DB_PATH"
chmod 644 "$DB_PATH"
print_success "Database restored successfully"

# Start the application
print_status "Starting application..."
docker-compose -f docker-compose.prod.yml start logistics-app

# Wait for application to start
sleep 10

# Health check
print_status "Performing health check..."
if curl -f http://localhost:3000/api/health > /dev/null 2>&1; then
    print_success "Application is running correctly after restoration"
else
    print_error "Health check failed. Check the logs:"
    docker-compose -f docker-compose.prod.yml logs logistics-app
fi

print_success "🔄 Database restoration completed successfully!"
echo ""
echo -e "${YELLOW}Restoration details:${NC}"
echo "  • Restored from: $(basename $BACKUP_FILE)"
echo "  • Backup created: $(basename $CURRENT_BACKUP)"
echo "  • Application status: $(docker-compose -f docker-compose.prod.yml ps logistics-app --format 'table {{.State}}')"