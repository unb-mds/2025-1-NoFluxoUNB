#!/bin/bash

# Test script to verify git permissions in Docker
echo "🧪 Testing Git Permissions in Docker Container..."

# Test git operations in a temporary container
docker run --rm \
  -v $(pwd):/app \
  -w /app \
  --user $(id -u):$(id -g) \
  node:18-bullseye \
  bash -c "
    echo '🔍 Testing git access...'
    echo 'Current user: $(whoami)'
    echo 'User ID: $(id)'
    ls -la .git/ | head -3
    git status --porcelain 2>&1 || echo 'Git operations failed'
  "

echo ""
echo "💡 If git operations failed above, run:"
echo "   sudo chown -R $(id -u):$(id -g) .git/"
echo "   (This fixes host-side permissions)" 