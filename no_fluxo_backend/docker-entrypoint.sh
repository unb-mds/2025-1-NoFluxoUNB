#!/bin/bash

# Docker entrypoint script for NoFluxo Backend
# Handles conditional arguments based on environment variables

echo "🐳 NoFluxo Docker Container Starting..."
echo "📂 Working directory: $(pwd)"
echo "🌱 Environment: ${NODE_ENV:-development}"
echo "🌿 Branch: ${GIT_BRANCH:-main}"

# Build the command with conditional arguments
COMMAND="python start_and_monitor.py --branch ${GIT_BRANCH:-main}"

# Add git credentials if provided
if [ -n "$GIT_USERNAME" ]; then
    COMMAND="$COMMAND --git-username \"$GIT_USERNAME\""
fi

if [ -n "$GIT_TOKEN" ]; then
    COMMAND="$COMMAND --git-token \"$GIT_TOKEN\""
fi

# Add fork location if provided
if [ -n "$FORK_LOCATION" ] && [ "$FORK_LOCATION" != "" ]; then
    echo "🍴 Fork location configured: $FORK_LOCATION"
    COMMAND="$COMMAND --fork-location \"$FORK_LOCATION\""
else
    echo "📝 No fork location configured (updates will only affect main repo)"
fi

echo "🚀 Starting with command: $COMMAND"
echo "============================================"

# Execute the command
eval $COMMAND 