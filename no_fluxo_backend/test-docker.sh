#!/bin/bash

# Test Docker Auto-Update Setup
echo "🧪 Testing NoFluxo Docker Auto-Update Setup..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found! Please copy docker.env.example to .env first"
    echo "   cp docker.env.example .env"
    exit 1
fi

# Check if SSL certificates exist
if [ -f "/etc/letsencrypt/live/no-fluxo-api.shop/fullchain.pem" ]; then
    echo "✅ Production SSL certificates found"
    SSL_STATUS="PRODUCTION"
else
    echo "⚠️  Production SSL certificates not found - using development mode"
    if [ ! -f "ssl/cert.pem" ]; then
        echo "📋 Generating development SSL certificates..."
        chmod +x generate-ssl.sh
        ./generate-ssl.sh
    fi
    SSL_STATUS="DEVELOPMENT"
fi

# Check git credentials
if grep -q "your_github_username" .env; then
    echo "⚠️  Git credentials not configured in .env"
    echo "   Please set GIT_USERNAME and GIT_TOKEN for auto-updates"
    GIT_STATUS="NOT_CONFIGURED"
else
    echo "✅ Git credentials configured"
    GIT_STATUS="CONFIGURED"
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running! Please start Docker first"
    exit 1
fi

echo ""
echo "📋 Setup Summary:"
echo "   SSL Certificates: $SSL_STATUS"
echo "   Git Auto-Update: $GIT_STATUS"
echo ""

# Offer to run the container
read -p "🚀 Start the NoFluxo containers? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🐳 Starting containers..."
    docker-compose down 2>/dev/null  # Stop any existing containers
    docker-compose up --build
else
    echo "👍 Setup complete! Run 'docker-compose up --build' when ready"
fi 