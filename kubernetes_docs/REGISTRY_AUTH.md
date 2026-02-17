# Docker Registry Authentication Guide

This document explains how authentication works for the private Docker registry running in the Kubernetes cluster and how to manage users.

## Overview

The registry uses **HTTP Basic Authentication** with passwords stored in `htpasswd` format. The credentials are stored in a Kubernetes secret and mounted into the registry pod.

## User Types

| Type                  | Purpose                          | Example                      |
| --------------------- | -------------------------------- | ---------------------------- |
| **Personal accounts** | Human users for manual push/pull | `john`, `jane`               |
| **Robot accounts**    | Automation (CI/CD, scripts)      | `ci-robot`, `github-actions` |

**Best Practice**: Always use robot accounts for automation, never personal credentials.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Client                             │
│                    docker login / push / pull                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Traefik Ingress (HTTPS)                      │
│               registry.kubernetes.crianex.com:443                │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Registry Pod (:5000)                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Environment Variables:                                  │    │
│  │    REGISTRY_AUTH=htpasswd                               │    │
│  │    REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  /auth/htpasswd (mounted from secret)                   │    │
│  │    user1:$2y$05$...                                     │    │
│  │    user2:$2y$05$...                                     │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Managing Users

### Prerequisites

You need `htpasswd` available. Options:
- Install on Ubuntu/Debian: `apt-get install apache2-utils`
- Install on macOS: `brew install httpd`
- Use Docker: `docker run --rm httpd:alpine htpasswd ...`

### View Current Users

```bash
# Get the current htpasswd content (usernames only, passwords are hashed)
kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d
```

### Add a New User

#### Option 1: Replace all users (recommended for simplicity)

```bash
# Generate htpasswd with all users (existing + new)
HTPASSWD=$(docker run --rm httpd:alpine sh -c '
  htpasswd -Bbn user1 password1
  htpasswd -Bbn user2 password2
  htpasswd -Bbn newuser newpassword
')

# Delete old secret and create new one
kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="$HTPASSWD"

# Restart registry to pick up changes
kubectl -n registry rollout restart deployment/registry
kubectl -n registry rollout status deployment/registry
```

#### Option 2: Append to existing users

```bash
# Get current htpasswd
CURRENT=$(kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d)

# Add new user
NEWUSER=$(docker run --rm httpd:alpine htpasswd -Bbn newuser newpassword)

# Combine and update
HTPASSWD="${CURRENT}
${NEWUSER}"

kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="$HTPASSWD"
kubectl -n registry rollout restart deployment/registry
```

### Remove a User

```bash
# Get current users, filter out the one to remove
HTPASSWD=$(kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d | grep -v "^usertoremove:")

# Update secret
kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="$HTPASSWD"
kubectl -n registry rollout restart deployment/registry
```

### Change a User's Password

```bash
# Get current users, remove the one to update
HTPASSWD=$(kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d | grep -v "^existinguser:")

# Add the user with new password
NEWENTRY=$(docker run --rm httpd:alpine htpasswd -Bbn existinguser newpassword)

# Combine and update
HTPASSWD="${HTPASSWD}
${NEWENTRY}"

kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="$HTPASSWD"
kubectl -n registry rollout restart deployment/registry
```

---

## Robot Accounts (for CI/CD)

Robot accounts are dedicated credentials for automation. They're more secure than using personal credentials because:

- ✅ Can be rotated independently without affecting human users
- ✅ Can be revoked instantly if compromised
- ✅ Easy to audit in logs (you know which system made requests)
- ✅ Limited blast radius if credentials leak

### Create a Robot Account

Run this on the `projeto` server:

```bash
# Generate a secure random password
CI_PASSWORD=$(openssl rand -base64 32)
CI_USER="ci-robot"

# Get current users
CURRENT=$(kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d)

# Add CI user
NEWUSER=$(docker run --rm httpd:alpine htpasswd -Bbn "$CI_USER" "$CI_PASSWORD")

# Update secret
kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="${CURRENT}
${NEWUSER}"

# Restart registry
kubectl -n registry rollout restart deployment/registry

# Display credentials
echo ""
echo "========================================="
echo "Robot account created!"
echo "========================================="
echo "Username: $CI_USER"
echo "Password: $CI_PASSWORD"
echo ""
echo "Add these to your GitHub Secrets:"
echo "  REGISTRY_USERNAME: $CI_USER"
echo "  REGISTRY_PASSWORD: $CI_PASSWORD"
echo "========================================="
```

### Rotate a Robot Account Password

When you need to rotate credentials (recommended every 90 days):

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)
ROBOT_USER="ci-robot"

# Get current users, remove the robot account
HTPASSWD=$(kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d | grep -v "^${ROBOT_USER}:")

# Add robot with new password
NEWENTRY=$(docker run --rm httpd:alpine htpasswd -Bbn "$ROBOT_USER" "$NEW_PASSWORD")

# Update secret
kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="${HTPASSWD}
${NEWENTRY}"
kubectl -n registry rollout restart deployment/registry

echo ""
echo "Password rotated for $ROBOT_USER"
echo "New password: $NEW_PASSWORD"
echo ""
echo "Don't forget to update:"
echo "  - GitHub Secrets (REGISTRY_PASSWORD)"
echo "  - Any regcred secrets in namespaces"
```

### Revoke a Robot Account

If a robot account is compromised:

```bash
ROBOT_USER="ci-robot"

# Remove the robot account
HTPASSWD=$(kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' | base64 -d | grep -v "^${ROBOT_USER}:")

kubectl -n registry delete secret registry-auth
kubectl -n registry create secret generic registry-auth --from-literal=htpasswd="$HTPASSWD"
kubectl -n registry rollout restart deployment/registry

echo "Robot account '$ROBOT_USER' has been revoked!"
```

### Recommended Robot Accounts

| Account Name       | Purpose                    | Used By                 |
| ------------------ | -------------------------- | ----------------------- |
| `ci-robot`         | GitHub Actions deployments | GitHub Actions workflow |
| `backup-robot`     | Automated backup scripts   | Backup cron jobs        |
| `monitoring-robot` | Health check systems       | Monitoring tools        |

---

## Client Configuration

### Docker CLI Login

```bash
# Interactive login
docker login registry.kubernetes.crianex.com

# Non-interactive login
docker login registry.kubernetes.crianex.com -u myuser -p mypassword

# Logout
docker logout registry.kubernetes.crianex.com
```

Credentials are stored in `~/.docker/config.json`.

### Kubernetes Image Pull Secret

For Kubernetes to pull images from the private registry, create an image pull secret:

```bash
# Create pull secret in a namespace
kubectl create secret docker-registry regcred \
  --docker-server=registry.kubernetes.crianex.com \
  --docker-username=myuser \
  --docker-password=mypassword \
  --docker-email=your@email.com \
  -n <namespace>
```

Use in deployments:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      imagePullSecrets:
      - name: regcred
      containers:
      - name: myapp
        image: registry.kubernetes.crianex.com/myapp:latest
```

Or set as default for a service account:

```bash
kubectl patch serviceaccount default -n <namespace> \
  -p '{"imagePullSecrets": [{"name": "regcred"}]}'
```

## Testing Authentication

```bash
# Should return 401 Unauthorized
curl -v https://registry.kubernetes.crianex.com/v2/

# Should return 200 OK with {}
curl -u myuser:mypassword https://registry.kubernetes.crianex.com/v2/

# List repositories
curl -u myuser:mypassword https://registry.kubernetes.crianex.com/v2/_catalog

# List tags for an image
curl -u myuser:mypassword https://registry.kubernetes.crianex.com/v2/myimage/tags/list
```

## Troubleshooting

### "unauthorized: authentication required"

- Verify credentials: `curl -u user:pass https://registry.kubernetes.crianex.com/v2/`
- Check the secret exists: `kubectl -n registry get secret registry-auth`
- Verify secret is mounted: `kubectl -n registry describe pod -l app=registry`

### "no basic auth credentials"

- Run `docker login registry.kubernetes.crianex.com`
- Check `~/.docker/config.json` for saved credentials

### Registry pod not starting

Check if the secret exists and is correctly formatted:

```bash
kubectl -n registry get secret registry-auth -o yaml
kubectl -n registry logs -l app=registry
```

### Image pull errors in pods

```bash
# Check events
kubectl describe pod <podname>

# Verify pull secret exists in the namespace
kubectl get secret regcred -n <namespace>

# Verify pull secret is referenced in deployment
kubectl get deployment <name> -o yaml | grep -A2 imagePullSecrets
```

## Security Best Practices

1. **Use strong passwords** - At least 16 characters with mixed case, numbers, symbols
2. **Rotate credentials regularly** - Update passwords every 90 days
3. **Use separate accounts** - Create individual accounts per user/service
4. **Limit access** - Only create accounts for users who need push/pull access
5. **Audit usage** - Check registry logs for unauthorized access attempts

```bash
# View registry logs
kubectl -n registry logs -l app=registry --tail=100
```

## Quick Reference

| Action           | Command                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------ |
| View users       | `kubectl -n registry get secret registry-auth -o jsonpath='{.data.htpasswd}' \| base64 -d` |
| Add user         | See "Add a New User" section                                                               |
| Remove user      | See "Remove a User" section                                                                |
| Change password  | See "Change a User's Password" section                                                     |
| Test auth        | `curl -u user:pass https://registry.kubernetes.crianex.com/v2/`                            |
| Docker login     | `docker login registry.kubernetes.crianex.com`                                             |
| Restart registry | `kubectl -n registry rollout restart deployment/registry`                                  |
