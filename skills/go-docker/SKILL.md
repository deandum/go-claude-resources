---
name: go-docker
description: >
  Docker containerization for Go applications: multi-stage builds, layer caching,
  static binaries, base image selection, and security. Use when containerizing Go
  services, optimizing images, or setting up CI/CD pipelines.
---

# Go Docker

Build small, secure, production-ready containers. Static binaries, distroless images, non-root users.

## When to Apply

Use this skill when:
- Containerizing Go applications for production
- Optimizing Docker image size and build time
- Setting up CI/CD pipelines with Docker
- Handling private Go modules in Docker builds
- Reviewing Dockerfiles for security and efficiency

## Decision Framework: Base Image Selection

| Base Image | Size | Use Case | Security |
|---|---|---|---|
| **scratch** | ~2MB | Static binaries only (CGO_ENABLED=0) | Minimal attack surface |
| **distroless/static** | ~2MB | Static binaries with better debugging | Minimal, no shell |
| **distroless/base** | ~20MB | CGO binaries, need libc | Minimal, no shell |
| **alpine** | ~5MB | Need shell/debugging tools | Small but has shell |
| **debian:slim** | ~70MB | Complex dependencies, debugging | Full OS tools |

**Decision Rule**: Use distroless/static for production (security + small size). Use alpine for development/debugging.

## Pattern 1: Multi-Stage Build (Production-Ready)

Build in one stage, run in minimal distroless image.

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy dependency files first (layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o app \
    ./cmd/api

# Stage 2: Runtime
FROM gcr.io/distroless/static:nonroot

# Copy binary from builder
COPY --from=builder /build/app /app

# Use non-root user (automatically provided by distroless:nonroot)
USER nonroot:nonroot

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app", "healthcheck"]

# Run application
ENTRYPOINT ["/app"]
```

**Build flags explained:**
- `CGO_ENABLED=0` - Build static binary (no C dependencies)
- `-ldflags='-w -s'` - Strip debug info and symbol table (smaller binary)
- `-extldflags "-static"` - Force static linking

**Rules:**
- Use multi-stage builds (builder + runtime)
- Build in golang image, run in distroless/static
- Copy only the binary to runtime image
- Use nonroot user for security

## Pattern 2: Layer Caching Optimization

Order Dockerfile instructions for maximum cache reuse.

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build

# 1. Copy dependency files FIRST (changes infrequently)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# 2. Copy source code LAST (changes frequently)
COPY . .

# 3. Build
RUN CGO_ENABLED=0 go build -o app ./cmd/api
```

**Layer Caching Strategy:**
1. Dependencies (go.mod, go.sum) - cached unless dependencies change
2. Source code - cached unless code changes
3. Build command - runs only if previous layers change

**Build time comparison:**
- First build: ~60s (download deps + build)
- Code change only: ~5s (reuse cached deps)
- Dependency change: ~60s (re-download deps + build)

## Pattern 3: .dockerignore (Reduce Build Context)

Exclude unnecessary files from build context.

```dockerignore
# .dockerignore

# Git
.git
.gitignore
.github

# Development
.vscode
.idea
*.swp
*.swo

# Documentation
README.md
docs/
*.md

# Testing
*_test.go
testdata/
coverage.out

# Build artifacts
bin/
dist/
*.exe

# Environment
.env
.env.local
*.pem
*.key

# Dependencies (downloaded in container)
vendor/

# CI/CD
.gitlab-ci.yml
.circleci/
Jenkinsfile

# Docker
Dockerfile
docker-compose.yml
```

**Benefits:**
- Faster builds (smaller context sent to Docker daemon)
- Smaller images (exclude unnecessary files)
- Security (no secrets accidentally copied)

## Pattern 4: Build Arguments and Metadata

Use build args for versioning and configuration.

```dockerfile
FROM golang:1.21-alpine AS builder

# Build arguments
ARG VERSION=dev
ARG BUILD_DATE
ARG GIT_COMMIT

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Inject build metadata via ldflags
RUN CGO_ENABLED=0 go build \
    -ldflags="-w -s \
    -X main.Version=${VERSION} \
    -X main.BuildDate=${BUILD_DATE} \
    -X main.GitCommit=${GIT_COMMIT}" \
    -o app ./cmd/api

FROM gcr.io/distroless/static:nonroot

# Labels for metadata (OCI standard)
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.title="My API"
LABEL org.opencontainers.image.description="Production API service"

COPY --from=builder /build/app /app

USER nonroot:nonroot

ENTRYPOINT ["/app"]
```

**Build command:**
```bash
docker build \
  --build-arg VERSION=$(git describe --tags --always) \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) \
  -t myapi:latest \
  .
```

## Pattern 5: Private Go Modules Without Exposing Secrets

Use Docker secrets or SSH for private module access without leaking credentials.

### Option 1: SSH Agent Forwarding (Recommended)

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.21-alpine AS builder

# Install git and SSH
RUN apk add --no-cache git openssh-client

WORKDIR /build

# Configure Git to use SSH for private repos
RUN git config --global url."git@github.com:".insteadOf "https://github.com/"

COPY go.mod go.sum ./

# Mount SSH agent socket (doesn't persist in image)
RUN --mount=type=ssh \
    go mod download

COPY . .

RUN CGO_ENABLED=0 go build -o app ./cmd/api

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**Build with SSH forwarding:**
```bash
# Ensure ssh-agent is running and key is added
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa

# Build with SSH mount
docker build --ssh default -t myapi:latest .
```

**Benefits:**
- SSH key never written to image layers
- No credentials in environment variables
- Works with GitHub, GitLab, Bitbucket

### Option 2: Build-Time Secrets (Docker BuildKit)

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git

WORKDIR /build

# Configure GOPRIVATE
ENV GOPRIVATE="github.com/yourorg/*"

COPY go.mod go.sum ./

# Mount secret file (ephemeral, not persisted)
RUN --mount=type=secret,id=github_token \
    git config --global url."https://$(cat /run/secrets/github_token)@github.com/".insteadOf "https://github.com/" && \
    go mod download && \
    git config --global --unset url.https://github.com/.insteadof

COPY . .
RUN CGO_ENABLED=0 go build -o app ./cmd/api

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**Build with secret:**
```bash
# Token from environment variable
docker build \
  --secret id=github_token,env=GITHUB_TOKEN \
  -t myapi:latest \
  .

# Or from file
docker build \
  --secret id=github_token,src=$HOME/.github_token \
  -t myapi:latest \
  .
```

### Option 3: Netrc for HTTPS Authentication

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build

ENV GOPRIVATE="github.com/yourorg/*"

COPY go.mod go.sum ./

# Mount .netrc file (ephemeral)
RUN --mount=type=secret,id=netrc,target=/root/.netrc \
    go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o app ./cmd/api

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**~/.netrc file:**
```
machine github.com
login your-username
password ghp_yourpersonalaccesstoken
```

**Build:**
```bash
docker build --secret id=netrc,src=$HOME/.netrc -t myapi:latest .
```

## Decision Framework: GOPRIVATE Authentication Method

| Method | Security | CI/CD Ease | Use Case |
|---|---|---|---|
| **SSH forwarding** | Best (no creds in image) | Requires SSH setup | Local dev, GitHub Actions |
| **Build secrets** | Good (ephemeral mount) | Easy with secret mgmt | GitLab CI, AWS/GCP |
| **Netrc** | Good (ephemeral mount) | Easy | HTTPS-only environments |

**Never do this:**
```dockerfile
# BAD: Token in ENV (persisted in layer!)
ENV GITHUB_TOKEN=ghp_abc123
```

## Pattern 6: Non-Root User Security

Always run containers as non-root user.

```dockerfile
# Using distroless:nonroot (user built-in)
FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]

# Using Alpine (create user manually)
FROM alpine:3.19
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /build/app /app
USER appuser:appgroup
ENTRYPOINT ["/app"]

# Using scratch (copy from builder with --chown)
FROM scratch
COPY --from=builder --chown=65532:65532 /build/app /app
USER 65532:65532
ENTRYPOINT ["/app"]
```

**User ID 65532:**
- Standard non-root user ID
- Used by distroless images
- Recognized by Kubernetes security contexts

## Pattern 7: Health Checks

Define health checks in Dockerfile for container orchestration.

```dockerfile
FROM gcr.io/distroless/static:nonroot

COPY --from=builder /build/app /app

USER nonroot:nonroot

EXPOSE 8080

# Health check using built-in endpoint
HEALTHCHECK --interval=30s \
            --timeout=3s \
            --start-period=5s \
            --retries=3 \
  CMD ["/app", "healthcheck"]

ENTRYPOINT ["/app"]
```

**Health check in Go code:**
```go
func main() {
	if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
		healthCheck()
		return
	}

	// Normal application startup
	startServer()
}

func healthCheck() {
	resp, err := http.Get("http://localhost:8080/health")
	if err != nil || resp.StatusCode != http.StatusOK {
		os.Exit(1)
	}
	os.Exit(0)
}
```

## Pattern 8: Size Optimization Comparison

```dockerfile
# ❌ BAD: 1.2GB (full golang image)
FROM golang:1.21
COPY . .
RUN go build -o app ./cmd/api
CMD ["/app"]

# ⚠️  BETTER: 800MB (alpine builder, but binary in alpine)
FROM golang:1.21-alpine
COPY . .
RUN go build -o app ./cmd/api
CMD ["/app"]

# ✅ BEST: 10-20MB (multi-stage with distroless)
FROM golang:1.21-alpine AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o app ./cmd/api

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

**Size comparison:**
- Full golang image: ~1.2GB
- Alpine with binary: ~800MB
- Multi-stage distroless: ~10-20MB (95% smaller!)

## Anti-Patterns

### Running as root

```dockerfile
# BAD: Running as root (security risk)
FROM alpine
COPY app /app
CMD ["/app"]

# GOOD: Non-root user
FROM gcr.io/distroless/static:nonroot
COPY app /app
USER nonroot:nonroot
CMD ["/app"]
```

### Not using .dockerignore

```dockerfile
# BAD: Copies everything (slow, large context)
COPY . .

# GOOD: With .dockerignore excluding unnecessary files
COPY . .  # But with .dockerignore filtering
```

### Installing unnecessary packages

```dockerfile
# BAD: Bloated runtime image
FROM alpine
RUN apk add --no-cache bash curl wget vim git
COPY app /app
CMD ["/app"]

# GOOD: Minimal runtime
FROM gcr.io/distroless/static:nonroot
COPY app /app
USER nonroot:nonroot
CMD ["/app"]
```

### Not pinning base image versions

```dockerfile
# BAD: Unpredictable builds
FROM golang:latest
FROM alpine

# GOOD: Pinned versions
FROM golang:1.21.5-alpine3.19
FROM gcr.io/distroless/static:nonroot-amd64@sha256:abc123...
```

### Exposing secrets in layers

```dockerfile
# BAD: Secret persists in layer history!
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=${GITHUB_TOKEN}
RUN git clone https://${GITHUB_TOKEN}@github.com/private/repo.git

# GOOD: Use --mount=type=secret
RUN --mount=type=secret,id=github_token \
    git clone https://$(cat /run/secrets/github_token)@github.com/private/repo.git
```

### Ignoring layer caching order

```dockerfile
# BAD: Code copied before deps (cache busted frequently)
COPY . .
RUN go mod download
RUN go build -o app ./cmd/api

# GOOD: Deps first, code second
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o app ./cmd/api
```

## Makefile Integration

```makefile
.PHONY: docker-build
docker-build:
	docker build \
		--build-arg VERSION=$(shell git describe --tags --always) \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg GIT_COMMIT=$(shell git rev-parse HEAD) \
		-t myapi:latest \
		.

.PHONY: docker-build-private
docker-build-private:
	docker build \
		--ssh default \
		--build-arg VERSION=$(shell git describe --tags --always) \
		-t myapi:latest \
		.

.PHONY: docker-run
docker-run:
	docker run -p 8080:8080 --rm myapi:latest

.PHONY: docker-scan
docker-scan:
	docker scan myapi:latest
```

## Security Scanning in CI/CD

```yaml
# .github/workflows/docker.yml
name: Docker Build

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapi:${{ github.sha }} .

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: myapi:${{ github.sha }}
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail build on vulnerabilities
```

## References

- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Distroless Images](https://github.com/GoogleContainerTools/distroless)
- [Docker BuildKit Secrets](https://docs.docker.com/build/building/secrets/)
