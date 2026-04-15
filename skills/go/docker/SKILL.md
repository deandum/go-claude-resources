---
name: go/docker
description: >
  Go Docker patterns. Multi-stage builds with CGO_ENABLED=0, ldflags,
  distroless images, build args. Extends core/docker with Go-specific
  build patterns.
---

# Go Docker

Static binaries + distroless = tiny, secure containers.

## Multi-Stage Build (Production)

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.24-alpine AS builder
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags='-w -s -extldflags "-static"' \
    -o app ./cmd/api

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /build/app /app
USER nonroot:nonroot
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app", "healthcheck"]
ENTRYPOINT ["/app"]
```

**Build flags:** `CGO_ENABLED=0` = static binary. `-ldflags='-w -s'` = strip debug/symbols. Typical size reduction for a Go service: alpine+golang builder image ~700MB → distroless runtime image ~15-30MB (depends on statically-linked deps; complex services with heavy imports can reach 50MB+). The `-w -s` strip saves roughly 25% by removing DWARF debug info and the symbol table — do not strip if you want readable panics with function names.

## Build Args for Metadata

```dockerfile
ARG VERSION=dev
ARG BUILD_DATE
ARG GIT_COMMIT

RUN CGO_ENABLED=0 go build \
    -ldflags="-w -s -X main.Version=${VERSION} -X main.BuildDate=${BUILD_DATE} -X main.GitCommit=${GIT_COMMIT}" \
    -o app ./cmd/api
```

```bash
docker build --build-arg VERSION=$(git describe --tags --always) \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg GIT_COMMIT=$(git rev-parse HEAD) -t myapi:latest .
```

## Health Check in Go

```go
func main() {
    if len(os.Args) > 1 && os.Args[1] == "healthcheck" {
        resp, err := http.Get("http://localhost:8080/health")
        if err != nil || resp.StatusCode != http.StatusOK { os.Exit(1) }
        os.Exit(0)
    }
    startServer()
}
```

## .dockerignore

```dockerignore
.git
.github
.vscode
.idea
*.md
docs/
*_test.go
testdata/
coverage.out
bin/
dist/
.env
*.pem
*.key
vendor/
Dockerfile
docker-compose.yml
```

## Non-Root User Patterns

```dockerfile
# distroless (built-in)
FROM gcr.io/distroless/static:nonroot
USER nonroot:nonroot

# alpine (create manually)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser:appgroup

# scratch (UID only)
COPY --from=builder --chown=65532:65532 /build/app /app
USER 65532:65532
```

## Additional Resources

- [private-modules.md](references/private-modules.md), [ci-cd.md](references/ci-cd.md)

## Verification

- [ ] `docker build` completes successfully with no errors
- [ ] Final image is under 50MB (use multi-stage build with distroless/scratch)
- [ ] Container runs as non-root user (`USER nonroot` or equivalent)
- [ ] `HEALTHCHECK` instruction present in Dockerfile
