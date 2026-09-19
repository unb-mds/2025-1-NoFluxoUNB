#!/bin/bash

# Environment Variable Test Script for NoFluxo Backend

echo "🔍 NoFluxo Environment Variable Test"
echo "===================================="


if [ -f ".env" ]; then
    echo "✅ .env file found in current directory"
    echo "📄 .env file contents (sanitized):"
    # Show environment variables but mask sensitive values
    grep -v "^#" .env | sed 's/=.*/=***MASKED***/' 2>/dev/null || echo "Could not read .env file"
else
    echo "❌ .env file not found in current directory"
fi

echo ""
echo "🐳 Docker Container Environment Test:"
echo "====================================="

# Test if we can access the container
if docker ps | grep -q no-fluxo-backend; then
    echo "✅ Docker container is running"
    
    echo ""
    echo "📁 Container file system check:"
    docker exec no-fluxo-backend ls -la /app/.env 2>/dev/null && echo "✅ .env file exists in container" || echo "❌ .env file missing in container"
    docker exec no-fluxo-backend ls -la /app/logs 2>/dev/null && echo "✅ logs directory exists in container" || echo "❌ logs directory missing in container"
    docker exec no-fluxo-backend ls -la /app/ai_agent/logs 2>/dev/null && echo "✅ ai_agent logs directory exists" || echo "❌ ai_agent logs directory missing"
    
    echo ""
    echo "🔧 Container environment variables:"
    docker exec no-fluxo-backend printenv | grep -E "(NODE_ENV|PORT|PYTHON)" | head -10
    
    echo ""
    echo "🐍 Python environment test:"
    docker exec no-fluxo-backend python -c "
import os
from dotenv import load_dotenv

print('Testing .env file loading...')
if os.path.exists('/app/.env'):
    print('✅ .env file found at /app/.env')
    load_dotenv('/app/.env')
    print('✅ .env file loaded successfully')
else:
    print('❌ .env file not found at /app/.env')

print('Environment variables:')
for key in ['NODE_ENV', 'PORT', 'AI_AGENT_PORT']:
    value = os.getenv(key, 'NOT_FOUND')
    print(f'{key}: {value}')
"
    
else
    echo "❌ Docker container 'no-fluxo-backend' is not running"
    echo "💡 Try running: docker-compose up -d"
fi

echo ""
echo "✨ Test completed!" 