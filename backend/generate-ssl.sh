#!/bin/bash

# Generate SSL certificates for development
echo "🔐 Generating SSL certificates for development..."

# Create ssl directory if it doesn't exist
mkdir -p ssl

# Generate private key
openssl genrsa -out ssl/key.pem 2048

# Generate certificate signing request
openssl req -new -key ssl/key.pem -out ssl/cert.csr -subj "/C=BR/ST=DF/L=Brasilia/O=NoFluxo/OU=Development/CN=localhost"

# Generate self-signed certificate
openssl x509 -req -in ssl/cert.csr -signkey ssl/key.pem -out ssl/cert.pem -days 365

# Clean up CSR file
rm ssl/cert.csr

# Set appropriate permissions
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem

echo "✅ SSL certificates generated successfully!"
echo "📁 Files created:"
echo "   - ssl/cert.pem (certificate)"
echo "   - ssl/key.pem (private key)"
echo ""
echo "⚠️  These are self-signed certificates for development only."
echo "   Your browser will show a security warning - this is expected."
echo ""
echo "🚀 You can now run: docker-compose up --build" 