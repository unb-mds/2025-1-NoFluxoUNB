#!/bin/bash

# Git Functionality Test Script for NoFluxo Backend

echo "🔍 NoFluxo Git Functionality Test"
echo "=================================="


echo "📋 Local Git Status:"
echo "===================="
if [ -d ".git" ]; then
    echo "✅ .git directory found"
    echo "🌿 Current branch: $(git branch --show-current 2>/dev/null || echo 'Unknown')"
    echo "📍 Current commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'Unknown')"
    echo "🔗 Remote URL: $(git remote get-url origin 2>/dev/null || echo 'No remote configured')"
else
    echo "❌ .git directory not found"
fi

echo ""
echo "🐳 Docker Container Git Test:"
echo "============================="

# Test if container is running
if docker ps | grep -q no-fluxo-backend; then
    echo "✅ Docker container is running"
    
    echo ""
    echo "📁 Container git structure:"
    docker exec no-fluxo-backend ls -la /app/.git 2>/dev/null && echo "✅ .git directory exists in container" || echo "❌ .git directory missing in container"
    
    echo ""
    echo "🔧 Container git configuration:"
    docker exec no-fluxo-backend git --version
    docker exec no-fluxo-backend git config --list | grep -E "(user\.|safe\.directory)" | head -5
    
    echo ""
    echo "📍 Container git status:"
    docker exec no-fluxo-backend bash -c "cd /app && pwd && git status --porcelain | head -5"
    docker exec no-fluxo-backend bash -c "cd /app && git branch --show-current"
    docker exec no-fluxo-backend bash -c "cd /app && git rev-parse --short HEAD"
    
    echo ""
    echo "🌐 Container git fetch test:"
    docker exec no-fluxo-backend bash -c "cd /app && git fetch origin 2>&1 | head -10"
    
    if [ $? -eq 0 ]; then
        echo "✅ Git fetch successful"
    else
        echo "⚠️  Git fetch failed (check network/credentials)"
    fi
    
    echo ""
    echo "🔍 Monitoring script status check:"
    docker exec no-fluxo-backend bash -c "cd /app && python -c \"
import os
os.chdir('/app')
print('Working directory:', os.getcwd())
print('Git directory exists:', os.path.exists('.git'))
print('start_and_monitor.py exists:', os.path.exists('start_and_monitor.py'))
\""
    
else
    echo "❌ Docker container 'no-fluxo-backend' is not running"
    echo "💡 Try running: docker-compose up -d"
fi

echo ""
echo "✨ Git test completed!" 