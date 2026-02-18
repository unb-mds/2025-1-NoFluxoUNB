# Go Dockerfile Template
# Copy to your project as "Dockerfile"

# Use internal registry mirror to avoid Docker Hub egress during in-cluster builds
FROM registry.kubernetes.crianex.com/library/golang:1.22-alpine AS builder

WORKDIR /app

# Download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /app/server .

# Minimal production image (scratch = empty image)
FROM scratch

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary
COPY --from=builder /app/server /server

# Application port - replace 8080 with your port
EXPOSE 8080

# Start command
ENTRYPOINT ["/server"]
