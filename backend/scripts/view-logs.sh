#!/bin/bash

# NoFluxo Backend Log Viewer
# This script helps view logs from different components

show_help() {
    echo "NoFluxo Backend Log Viewer"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  all       Show logs from all containers"
    echo "  backend   Show logs from backend container only"
    echo "  nginx     Show logs from nginx container only"
    echo "  python    Show Python logs from file (inside container)"
    echo "  follow    Follow all logs in real-time"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 all          # Show all logs"
    echo "  $0 follow       # Follow logs in real-time"
    echo "  $0 backend      # Show only backend logs"
}

case "$1" in
    "all")
        echo "=== Showing logs from all containers ==="
        docker-compose logs --tail=100
        ;;
    "backend")
        echo "=== Showing backend container logs ==="
        docker-compose logs --tail=100 no-fluxo-backend
        ;;
    "nginx")
        echo "=== Showing nginx container logs ==="
        docker-compose logs --tail=100 no-fluxo-nginx
        ;;
    "python")
        echo "=== Showing Python log files from container ==="
        echo "Process logs:"
        docker exec no-fluxo-backend tail -50 /app/logs/process.log 2>/dev/null || echo "No process.log found"
        ;;
    "follow")
        echo "=== Following all logs in real-time (Ctrl+C to stop) ==="
        docker-compose logs -f
        ;;
    "help"|*)
        show_help
        ;;
esac 