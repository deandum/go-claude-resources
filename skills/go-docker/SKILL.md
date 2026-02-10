---
name: go-docker
description: >
  Docker containerization for Go applications: multi-stage builds, layer caching,
  static binaries, base image selection, and security. Use when containerizing Go
  services, optimizing images, or setting up CI/CD pipelines.
---

# Go Docker

Build small, secure, production-ready containers. Static binaries, distroless images, non-root users.

## Contents

- [Decision Framework: Base Image Selection](#decision-framework-base-image-selection)
- [Pattern 1: Multi-Stage Build (Production-Ready)](#pattern-1-multi-stage-build-production-ready)
- [Pattern 2: Layer Caching Optimization](#pattern-2-layer-caching-optimization)
- [Pattern 3: .dockerignore (Reduce Build Context)](#pattern-3-dockerignore-reduce-build-context)
- [Pattern 4: Build Arguments and Metadata](#pattern-4-build-arguments-and-metadata)
- [Pattern 5: Non-Root User Security](#pattern-5-non-root-user-security)
- [Pattern 6: Health Checks](#pattern-6-health-checks)
- [Anti-Patterns](#anti-patterns)
- [Additional Resources](#additional-resources)

**Note:** Examples use `golang:1.24-alpine` — always substitute the latest stable Go release.

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
FROM golang:1.24-alpine AS builder

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

**Size impact:** Full golang image ~1.2GB → multi-stage distroless ~10-20MB (95% smaller).

## Pattern 2: Layer Caching Optimization

Order Dockerfile instructions for maximum cache reuse.

```dockerfile
FROM golang:1.24-alpine AS builder

WORKDIR /build

# 1. Copy dependency files FIRST (changes infrequently)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# 2. Copy source code LAST (changes frequently)
COPY . .

# 3. Build
RUN CGO_ENABLED=0 go build -o app ./cmd/api
```

**Build time impact:** Code-only changes reuse cached dependency layers (~5s vs ~60s full build).

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

## Pattern 4: Build Arguments and Metadata

Use build args for versioning and configuration.

```dockerfile
FROM golang:1.24-alpine AS builder

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

## Pattern 5: Non-Root User Security

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

## Pattern 6: Health Checks

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

## Anti-Patterns

### Not pinning base image versions

```dockerfile
# BAD: Unpredictable builds
FROM golang:latest
FROM alpine

# GOOD: Pinned versions
FROM golang:1.24.5-alpine3.19
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

### Installing unnecessary packages in runtime

```dockerfile
# BAD: Bloated runtime image
FROM alpine
RUN apk add --no-cache bash curl wget vim git
COPY app /app

# GOOD: Use distroless (see Pattern 1)
```

## Additional Resources

- For handling private Go modules in Docker builds, see [private-modules.md](references/private-modules.md)
- For Makefile targets and CI/CD security scanning, see [ci-cd.md](references/ci-cd.md)
