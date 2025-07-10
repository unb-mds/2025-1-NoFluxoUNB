#!/bin/bash

# Docker entrypoint script for NoFluxo Backend
# Handles conditional arguments and fork repository cloning

echo "🐳 NoFluxo Docker Container Starting..."
echo "📂 Working directory: $(pwd)"
echo "🌱 Environment: ${NODE_ENV:-development}"
echo "🌿 Branch: ${GIT_BRANCH:-main}"

# Create git config directory for appuser with proper permissions
echo "🔧 Setting up git configuration directory..."
sudo mkdir -p /home/appuser
sudo touch /home/appuser/.gitconfig
sudo chown appuser:appuser /home/appuser /home/appuser/.gitconfig

# Fix ownership of mounted repository for git operations
echo "🔧 Fixing mounted repository permissions..."
if [ -d "/app/.git" ]; then
    # Check if .git directory has content
    GIT_CONTENT_COUNT=$(find /app/.git -type f 2>/dev/null | wc -l)
    echo "🔍 Found $GIT_CONTENT_COUNT files in .git directory"
    
    if [ "$GIT_CONTENT_COUNT" -lt 5 ]; then
        echo "⚠️  .git directory appears incomplete (only $GIT_CONTENT_COUNT files)"
        echo "💡 This usually means the host repository is not properly initialized"
        echo "💡 Please ensure you run 'git init' and have commits in the host repository"
    else
        echo "✅ .git directory appears to have content"
    fi
    
    # Fix ownership of .git directory
    sudo chown -R appuser:appuser /app/.git
    echo "✅ Fixed .git directory ownership"
else
    echo "⚠️  .git directory not found - auto-updates will not work"
fi

# Fix ownership of all log directories  
sudo chown -R appuser:appuser /app/logs /app/no_fluxo_backend/logs /app/fork_repo 2>/dev/null || echo "📝 Some directories don't exist yet (normal)"
sudo chmod 775 /app/logs 2>/dev/null || echo "📝 /app/logs directory setup"

# Configure git for mounted volumes
echo "🔧 Configuring git for mounted directories..."
git config --global --add safe.directory /app
git config --global --add safe.directory '/app/*'
git config --global --add safe.directory '*'
export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

# Set basic git configuration if not set
git config --global user.email "docker@nofluxo.com" 2>/dev/null || true
git config --global user.name "Docker Container" 2>/dev/null || true

# Verify git setup and debug permissions
if [ -d "/app/.git" ]; then
    echo "✅ Git repository found"
    cd /app
    
    # Debug git directory permissions and content
    echo "🔍 Git directory info:"
    ls -la .git/ | head -5
    echo "🔍 Git directory file count: $(find .git -type f 2>/dev/null | wc -l)"
    echo "🔍 Current user: $(whoami)"
    echo "🔍 Current user ID: $(id)"
    
    # Test git operations with detailed output
    if git status --porcelain > /dev/null 2>&1; then
        echo "✅ Git operations working"
        echo "📋 Current branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
        echo "📋 Git status: $(git status --porcelain | wc -l) changed files"
    else
        echo "⚠️  Git operations still have issues, checking repository structure..."
        
        # Check for essential git files
        if [ ! -f ".git/HEAD" ]; then
            echo "❌ .git/HEAD file missing - repository may be corrupted"
        fi
        if [ ! -d ".git/refs" ]; then
            echo "❌ .git/refs directory missing - repository may be corrupted"
        fi
        if [ ! -f ".git/config" ]; then
            echo "❌ .git/config file missing - repository may be corrupted"
        fi
        
        echo "💡 Please check that your host repository is properly initialized:"
        echo "   cd $(pwd) && git status"
        echo "❌ Auto-updates will not work due to git repository issues"
    fi
    cd -
else
    echo "⚠️  Git repository not found"
fi

# Build the command with conditional arguments (working from backend directory)
COMMAND="cd /app/no_fluxo_backend && python start_and_monitor.py --branch ${GIT_BRANCH:-main}"

# Add git credentials if provided
if [ -n "$GIT_USERNAME" ]; then
    COMMAND="$COMMAND --git-username \"$GIT_USERNAME\""
fi

if [ -n "$GIT_TOKEN" ]; then
    COMMAND="$COMMAND --git-token \"$GIT_TOKEN\""
fi

# Handle fork repository cloning
if [ -n "$FORK_URL" ] && [ "$FORK_URL" != "" ]; then
    echo "🍴 Fork URL configured: $FORK_URL"
    
    FORK_DIR="/app/fork_repo"
    
    # Check if fork directory already exists and is a valid git repository
    if [ -d "$FORK_DIR" ] && [ -d "$FORK_DIR/.git" ]; then
        echo "📁 Fork directory exists, pulling latest changes..."
        cd "$FORK_DIR"
        
        # Setup git credentials for this repository
        if [ -n "$GIT_USERNAME" ] && [ -n "$GIT_TOKEN" ]; then
            # Configure git to use credentials
            git config credential.helper store
            echo "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com" > /app/.git-credentials
        fi
        
        git pull origin main 2>/dev/null || echo "⚠️  Could not pull fork updates"
        cd /app
    elif [ -d "$FORK_DIR" ]; then
        echo "📁 Fork directory exists but is not a git repository, removing..."
        rm -rf "$FORK_DIR" 2>/dev/null || echo "⚠️  Could not remove fork directory, continuing..."
        echo "📦 Cloning fork repository..."
        
        # Clone with credentials embedded in URL
        if [ -n "$GIT_USERNAME" ] && [ -n "$GIT_TOKEN" ]; then
            # Ensure the URL ends with .git
            CLEANED_FORK_URL="$FORK_URL"
            if [[ ! "$CLEANED_FORK_URL" == *.git ]]; then
                CLEANED_FORK_URL="${CLEANED_FORK_URL}.git"
                echo "🔧 Added .git extension: $CLEANED_FORK_URL"
            fi
            
            # Extract the github.com part and add credentials
            REPO_PATH=$(echo "$CLEANED_FORK_URL" | sed 's/https:\/\/github\.com\///')
            AUTHENTICATED_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${REPO_PATH}"
            
            git clone "$AUTHENTICATED_URL" "$FORK_DIR" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "✅ Fork cloned successfully"
                
                # Clean up the URL to remove embedded credentials for security
                cd "$FORK_DIR"
                git remote set-url origin "$CLEANED_FORK_URL"
                
                # Setup credential helper for future operations
                git config credential.helper store
                echo "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com" > /app/.git-credentials
                cd /app
            else
                echo "❌ Failed to clone fork repository"
                FORK_DIR=""
            fi
        else
            echo "❌ Git credentials required for fork cloning"
            FORK_DIR=""
        fi
    else
        echo "📦 Cloning fork repository..."
        
        # Clone with credentials embedded in URL
        if [ -n "$GIT_USERNAME" ] && [ -n "$GIT_TOKEN" ]; then
            # Ensure the URL ends with .git
            CLEANED_FORK_URL="$FORK_URL"
            if [[ ! "$CLEANED_FORK_URL" == *.git ]]; then
                CLEANED_FORK_URL="${CLEANED_FORK_URL}.git"
                echo "🔧 Added .git extension: $CLEANED_FORK_URL"
            fi
            
            # Extract the github.com part and add credentials
            REPO_PATH=$(echo "$CLEANED_FORK_URL" | sed 's/https:\/\/github\.com\///')
            AUTHENTICATED_URL="https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/${REPO_PATH}"
            
            git clone "$AUTHENTICATED_URL" "$FORK_DIR" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "✅ Fork cloned successfully"
                
                # Clean up the URL to remove embedded credentials for security
                cd "$FORK_DIR"
                git remote set-url origin "$CLEANED_FORK_URL"
                
                # Setup credential helper for future operations
                git config credential.helper store
                echo "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com" > /app/.git-credentials
                cd /app
            else
                echo "❌ Failed to clone fork repository"
                FORK_DIR=""
            fi
        else
            echo "❌ Git credentials required for fork cloning"
            FORK_DIR=""
        fi
    fi
    
    # Add fork location to command if cloning was successful
    if [ -n "$FORK_DIR" ] && [ -d "$FORK_DIR" ]; then
        echo "🎯 Using fork location: $FORK_DIR"
        COMMAND="$COMMAND --fork-location \"$FORK_DIR\""
    else
        echo "⚠️  Fork cloning failed, continuing without fork sync"
    fi
else
    echo "📝 No fork URL configured (updates will only affect main repo)"
fi

# Mask the token in the output for security
MASKED_COMMAND=$(echo "$COMMAND" | sed 's/--git-token "[^"]*"/--git-token "***"/g')
echo "🚀 Starting with command: $MASKED_COMMAND"
echo "============================================"

# Execute the command
eval $COMMAND 