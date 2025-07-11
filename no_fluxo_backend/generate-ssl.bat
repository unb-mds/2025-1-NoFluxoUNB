@echo off
echo 🔐 Generating SSL certificates for development...

REM Create ssl directory if it doesn't exist
if not exist "ssl" mkdir ssl

REM Check if OpenSSL is available
openssl version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ OpenSSL not found. Please install OpenSSL first:
    echo    - Download from: https://slproweb.com/products/Win32OpenSSL.html
    echo    - Or install via chocolatey: choco install openssl
    pause
    exit /b 1
)

REM Generate private key
openssl genrsa -out ssl/key.pem 2048

REM Generate certificate signing request
openssl req -new -key ssl/key.pem -out ssl/cert.csr -subj "/C=BR/ST=DF/L=Brasilia/O=NoFluxo/OU=Development/CN=localhost"

REM Generate self-signed certificate
openssl x509 -req -in ssl/cert.csr -signkey ssl/key.pem -out ssl/cert.pem -days 365

REM Clean up CSR file
del ssl/cert.csr

echo ✅ SSL certificates generated successfully!
echo 📁 Files created:
echo    - ssl/cert.pem (certificate)
echo    - ssl/key.pem (private key)
echo.
echo ⚠️  These are self-signed certificates for development only.
echo    Your browser will show a security warning - this is expected.
echo.
echo 🚀 You can now run: docker-compose up --build
pause 