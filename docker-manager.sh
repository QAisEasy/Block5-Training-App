#!/bin/bash

# Define project name for container naming
PROJECT_NAME="ecommerce"

# Define the paths to the Docker Compose files
DB_COMPOSE_FILE="docker-compose-db.yml"
APP_COMPOSE_FILE="docker-compose-product-service.yml"
SALES_COMPOSE_FILE="docker-compose-sales-service.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to stop all containers
stop_containers() {
    print_status "Stopping all containers..."
    
    docker-compose -p $PROJECT_NAME -f "$SALES_COMPOSE_FILE" down --remove-orphans
    docker-compose -p $PROJECT_NAME -f "$APP_COMPOSE_FILE" down --remove-orphans
    docker-compose -p $PROJECT_NAME -f "$DB_COMPOSE_FILE" down --remove-orphans
    
    print_status "All containers stopped."
}

# Function to start all containers with environment variables
start_containers() {
    print_status "Starting containers..."
    
    # Load environment variables from .env files (if present)
    if [ -f .env.db ]; then
        export $(cat .env.db | grep -v '^#' | xargs)
        print_status "Loaded database environment variables"
    else
        print_warning "No .env.db file found, using defaults"
    fi

    if [ -f .env.app ]; then
        export $(cat .env.app | grep -v '^#' | xargs)
        print_status "Loaded app environment variables"
    else
        print_warning "No .env.app file found, using defaults"
    fi

    if [ -f .env.sales ]; then
        export $(cat .env.sales | grep -v '^#' | xargs)
        print_status "Loaded sales environment variables"
    else
        print_warning "No .env.sales file found, using defaults"
    fi

    # Start the containers
    print_status "Starting database container..."
    docker-compose -p $PROJECT_NAME -f "$DB_COMPOSE_FILE" up -d
    
    # Wait for database to be ready
    print_status "Waiting for database to be ready..."
    sleep 10
    
    print_status "Starting product service container..."
    docker-compose -p $PROJECT_NAME -f "$APP_COMPOSE_FILE" up -d
    
    print_status "Starting sales service container..."
    docker-compose -p $PROJECT_NAME -f "$SALES_COMPOSE_FILE" up -d
    
    print_status "All containers started successfully!"
}

# Function to show container status
status_containers() {
    print_status "Container status:"
    docker-compose -p $PROJECT_NAME -f "$DB_COMPOSE_FILE" ps
    docker-compose -p $PROJECT_NAME -f "$APP_COMPOSE_FILE" ps
    docker-compose -p $PROJECT_NAME -f "$SALES_COMPOSE_FILE" ps
}

# Function to show logs
show_logs() {
    service=$1
    if [ -z "$service" ]; then
        print_error "Please specify a service: db, product, sales, or all"
        exit 1
    fi
    
    case "$service" in
        "db")
            docker-compose -p $PROJECT_NAME -f "$DB_COMPOSE_FILE" logs -f
            ;;
        "product")
            docker-compose -p $PROJECT_NAME -f "$APP_COMPOSE_FILE" logs -f
            ;;
        "sales")
            docker-compose -p $PROJECT_NAME -f "$SALES_COMPOSE_FILE" logs -f
            ;;
        "all")
            docker-compose -p $PROJECT_NAME -f "$DB_COMPOSE_FILE" logs &
            docker-compose -p $PROJECT_NAME -f "$APP_COMPOSE_FILE" logs &
            docker-compose -p $PROJECT_NAME -f "$SALES_COMPOSE_FILE" logs &
            wait
            ;;
        *)
            print_error "Unknown service: $service"
            exit 1
            ;;
    esac
}

# Function to restart containers
restart_containers() {
    stop_containers
    start_containers
}

# Function to rebuild containers
rebuild_containers() {
    print_status "Rebuilding containers..."
    
    docker-compose -p $PROJECT_NAME -f "$DB_COMPOSE_FILE" build
    docker-compose -p $PROJECT_NAME -f "$APP_COMPOSE_FILE" build --no-cache
    docker-compose -p $PROJECT_NAME -f "$SALES_COMPOSE_FILE" build --no-cache
    
    print_status "Containers rebuilt successfully!"
}

# Check Docker before running any command
check_docker

# Main script logic
case "$1" in
    "start")
        start_containers
        ;;
    "stop")
        stop_containers
        ;;
    "restart")
        restart_containers
        ;;
    "status")
        status_containers
        ;;
    "logs")
        show_logs $2
        ;;
    "rebuild")
        rebuild_containers
        ;;
    "rebuild-start")
        rebuild_containers
        start_containers
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|rebuild|rebuild-start}"
        echo ""
        echo "Commands:"
        echo "  start         - Start all containers"
        echo "  stop          - Stop all containers"
        echo "  restart       - Restart all containers"
        echo "  status        - Show container status"
        echo "  logs [service] - Show logs (service: db, product, sales, all)"
        echo "  rebuild       - Rebuild all containers"
        echo "  rebuild-start - Rebuild and start all containers"
        exit 1
        ;;
esac

exit 0
