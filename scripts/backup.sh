#!/bin/bash

# Database Backup Script
# This script creates backups of the SQLite database

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/home/deployer/gifs-landing-page"
BACKUP_DIR="/home/deployer/backups"
DB_PATH="$APP_DIR/data/database.db"
MAX_BACKUPS=30  # Keep 30 days of backups

# Function to print status
print_status() {
    echo -e "${YELLOW}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/database_backup_$DATE.db"

print_status "Creating database backup..."

# Check if database file exists
if [ ! -f "$DB_PATH" ]; then
    echo "Database file not found: $DB_PATH"
    exit 1
fi

# Create backup
cp "$DB_PATH" "$BACKUP_FILE"

# Compress backup to save space
gzip "$BACKUP_FILE"
BACKUP_FILE="$BACKUP_FILE.gz"

print_success "Database backup created: $(basename $BACKUP_FILE)"

# Clean up old backups
print_status "Cleaning up old backups (keeping last $MAX_BACKUPS)..."
cd "$BACKUP_DIR"
ls -t database_backup_*.db.gz 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm --

BACKUP_COUNT=$(ls database_backup_*.db.gz 2>/dev/null | wc -l)
print_success "Backup cleanup completed. $BACKUP_COUNT backups remaining."

# Display backup info
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
print_success "Backup size: $BACKUP_SIZE"

echo ""
echo "Available backups:"
ls -lah "$BACKUP_DIR"/database_backup_*.db.gz 2>/dev/null | tail -5 || echo "No backups found"