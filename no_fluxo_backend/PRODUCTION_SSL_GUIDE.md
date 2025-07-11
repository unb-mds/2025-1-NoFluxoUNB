# Production SSL Certificate Setup Guide

## 🏭 Production SSL Certificate Placement

### **Recommended Directory Structure on Production Server:**

```
/etc/ssl/
├── certs/
│   ├── nofluxo.com.crt          # Your domain certificate
│   ├── nofluxo.com.ca-bundle    # CA bundle (if required)
│   └── fullchain.pem            # Certificate + CA bundle combined
└── private/
    └── nofluxo.com.key          # Private key (600 permissions!)
```

## 🔐 SSL Certificate Options

### **Option 1: Let's Encrypt (FREE, Recommended)**

```bash
# Install certbot on your production server
sudo apt install certbot

# Get certificates for your domain
sudo certbot certonly --standalone -d nofluxo.com -d www.nofluxo.com

# Certificates will be placed in:
# /etc/letsencrypt/live/nofluxo.com/fullchain.pem
# /etc/letsencrypt/live/nofluxo.com/privkey.pem
```

### **Option 2: Commercial CA (Cloudflare, DigiCert, etc.)**

Purchase SSL certificate and download:
- `certificate.crt` (your certificate)
- `private.key` (your private key)  
- `ca-bundle.crt` (CA intermediate certificates)

### **Option 3: Cloud Provider SSL**

- **AWS**: Use AWS Certificate Manager + Application Load Balancer
- **Google Cloud**: Use Google-managed SSL certificates
- **Azure**: Use Azure Key Vault + Application Gateway

## 🐳 Production Docker Configuration

### **Update docker-compose.yml for Production:**

```yaml
version: '3.8'

services:
  no-fluxo-backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: no-fluxo-backend
    environment:
      - NODE_ENV=production
      - PORT=3325
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs
      - ./uploads:/app/uploads
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3325/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - no-fluxo-network

  nginx:
    image: nginx:alpine
    container_name: no-fluxo-nginx
    ports:
      - "443:443"     # HTTPS only in production
      - "4652:4652"   # AI Agent HTTPS
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      # Mount REAL SSL certificates from host
      - /etc/letsencrypt/live/nofluxo.com/fullchain.pem:/etc/ssl/certs/cert.pem:ro
      - /etc/letsencrypt/live/nofluxo.com/privkey.pem:/etc/ssl/private/key.pem:ro
    depends_on:
      - no-fluxo-backend
    restart: unless-stopped
    networks:
      - no-fluxo-network

networks:
  no-fluxo-network:
    driver: bridge
```

### **Update nginx.conf for Production:**

```nginx
events {
    worker_connections 1024;
}

http {
    upstream backend_main {
        server no-fluxo-backend:3325;
    }

    upstream backend_ai {
        server no-fluxo-backend:4652;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name nofluxo.com www.nofluxo.com;
        return 301 https://$server_name$request_uri;
    }

    # Main backend server (HTTPS)
    server {
        listen 443 ssl http2;
        server_name nofluxo.com www.nofluxo.com;

        # SSL Configuration
        ssl_certificate /etc/ssl/certs/cert.pem;
        ssl_certificate_key /etc/ssl/private/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;
        add_header X-XSS-Protection "1; mode=block";

        location / {
            proxy_pass http://backend_main;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
    }

    # AI Agent server (HTTPS)
    server {
        listen 4652 ssl http2;
        server_name nofluxo.com www.nofluxo.com;

        # Same SSL configuration
        ssl_certificate /etc/ssl/certs/cert.pem;
        ssl_certificate_key /etc/ssl/private/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        location / {
            proxy_pass http://backend_ai;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
    }
}
```

## 🔧 Production Setup Steps

### **1. On Your Production Server:**

```bash
# 1. Get SSL certificates (Let's Encrypt example)
sudo certbot certonly --standalone -d yourdomain.com

# 2. Verify certificate files exist
sudo ls -la /etc/letsencrypt/live/yourdomain.com/

# 3. Set proper permissions
sudo chmod 600 /etc/letsencrypt/live/yourdomain.com/privkey.pem
sudo chmod 644 /etc/letsencrypt/live/yourdomain.com/fullchain.pem

# 4. Create auto-renewal cron job
sudo crontab -e
# Add: 0 3 * * * certbot renew --quiet && docker-compose restart nginx
```

### **2. Update Docker Compose:**

```bash
# Update volume mounts to point to real certificates
# Replace /etc/letsencrypt/live/yourdomain.com/ with your actual paths
```

### **3. Update nginx.conf:**

```bash
# Replace server_name localhost with your actual domain
# Add security headers and HTTP to HTTPS redirect
```

### **4. Deploy:**

```bash
# Deploy to production
docker-compose up -d --build
```

## 🛡️ Security Best Practices

### **File Permissions:**
```bash
# Certificate files
sudo chmod 644 /etc/ssl/certs/cert.pem
# Private key (CRITICAL!)
sudo chmod 600 /etc/ssl/private/key.pem
# Owner should be root
sudo chown root:root /etc/ssl/certs/cert.pem /etc/ssl/private/key.pem
```

### **Firewall Configuration:**
```bash
# Only allow HTTPS ports
sudo ufw allow 443/tcp
sudo ufw allow 4652/tcp
# Block HTTP in production (nginx will redirect)
sudo ufw deny 80/tcp
```

### **Certificate Monitoring:**
- Set up monitoring for certificate expiration
- Let's Encrypt certificates expire every 90 days
- Set up automatic renewal

## 📍 Quick Reference

| Environment                    | Certificate Location                             | Docker Volume Mount                                                         |
| ------------------------------ | ------------------------------------------------ | --------------------------------------------------------------------------- |
| **Development**                | `./ssl/cert.pem`                                 | `./ssl/cert.pem:/etc/ssl/certs/cert.pem`                                    |
| **Production (Let's Encrypt)** | `/etc/letsencrypt/live/domain.com/fullchain.pem` | `/etc/letsencrypt/live/domain.com/fullchain.pem:/etc/ssl/certs/cert.pem:ro` |
| **Production (Commercial)**    | `/etc/ssl/certs/domain.com.crt`                  | `/etc/ssl/certs/domain.com.crt:/etc/ssl/certs/cert.pem:ro`                  |

## ⚠️ Important Notes

1. **Never commit real SSL certificates to git**
2. **Use read-only mounts (`:ro`) in production**
3. **Set up certificate renewal automation**
4. **Monitor certificate expiration dates**
5. **Use strong file permissions (600 for private keys)** 