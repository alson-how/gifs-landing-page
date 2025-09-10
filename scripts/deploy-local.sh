#!/bin/bash

# Local Development Deployment Script
# This script deploys the application locally for testing

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration - use current directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
APP_DIR="$CURRENT_DIR"
BACKUP_DIR="$APP_DIR/backups"

echo -e "${GREEN}🚀 Starting local deployment process...${NC}"

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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running or not accessible"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup current database if it exists
if [ -f "$APP_DIR/data/database.db" ]; then
    print_status "Creating database backup..."
    DATE=$(date +%Y%m%d_%H%M%S)
    cp "$APP_DIR/data/database.db" "$BACKUP_DIR/database_backup_$DATE.db"
    print_success "Database backed up to database_backup_$DATE.db"
fi

# Navigate to application directory
cd "$APP_DIR"

# Check if .env exists
if [ ! -f ".env" ]; then
    print_error ".env file not found. Please create it from .env.example"
    exit 1
fi

# Create required directories
print_status "Creating required directories..."
mkdir -p data ssl logs backups
chmod 755 data ssl logs backups

# Stop existing containers gracefully
print_status "Stopping existing containers..."
if docker-compose ps -q | grep -q .; then
    docker-compose down
    print_success "Containers stopped"
else
    print_success "No containers running"
fi

# Build and start new containers (development mode)
print_status "Building and starting containers..."
docker-compose up -d --build

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Check if services are running
print_status "Checking service status..."
if docker-compose ps | grep -q "Up"; then
    print_success "Services are running"
else
    print_error "Some services failed to start"
    docker-compose logs
    exit 1
fi

# Health check
print_status "Performing health check..."
sleep 10
if curl -f http://localhost:3000/api/health > /dev/null 2>&1; then
    print_success "Health check passed"
else
    print_error "Health check failed"
    docker-compose logs logistics-app
    exit 1
fi

# Clean up old Docker images
print_status "Cleaning up old Docker images..."
docker image prune -f > /dev/null 2>&1
print_success "Docker cleanup completed"

# Display status
print_status "Deployment status:"
docker-compose ps

print_success "🎉 Local deployment completed successfully!"
echo ""
echo -e "${GREEN}Your application is now running at:${NC}"
echo "  • HTTP: http://localhost:3000"
echo "  • Health Check: http://localhost:3000/api/health"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  • View logs: docker-compose logs -f"
echo "  • Restart: docker-compose restart"
echo "  • Stop: docker-compose down"
echo ""
echo -e "${YELLOW}For production deployment on DigitalOcean:${NC}"
echo "  • Follow the DEPLOYMENT.md guide"
echo "  • Use the deploy.sh script on the server"