---
name: docker
description: >
  Containerization principles. Use when containerizing for production,
  optimizing images, or reviewing Dockerfiles. Pair with language-specific
  docker skill for build patterns.
---

# Docker

Build small, secure, production-ready containers.

## When to Use

- Containerizing an application for production
- Optimizing Docker image size or build time
- Reviewing Dockerfiles for security and best practices
- Setting up CI/CD container pipelines

## When NOT to Use

- Local development without containers
- Writing language-specific build stages (use `<lang>/docker` skill)

## Core Process

1. **Choose base image** — smallest image that meets runtime needs
2. **Multi-stage build** — build in SDK image, run in minimal image
3. **Optimize layers** — dependency manifests first, source code last
4. **Secure the image** — non-root user, no secrets in layers, pinned versions
5. **Add health checks** — container orchestrators need them
6. **Configure .dockerignore** — reduce build context
7. **Verify** — build, check size, run as non-root, test health check

## Base Image Selection

| Image Type | Size | Use Case |
|---|---|---|
| scratch | ~0MB | Static binaries only |
| distroless/static | ~2MB | Static binaries, better debugging |
| distroless/base | ~20MB | Binaries needing libc |
| alpine | ~5MB | Need shell/debugging tools |
| debian:slim | ~70MB | Complex dependencies |

**Default**: distroless/static for production. Alpine for development/debugging.

## Multi-Stage Builds

1. **Build stage**: full SDK/toolchain, compile application
2. **Runtime stage**: minimal image, copy only binary/artifacts

Size reduction: 90-95% vs single-stage builds.

## Layer Caching

Order for maximum cache reuse:
1. Copy dependency manifests (changes infrequently)
2. Install dependencies
3. Copy source code (changes frequently)
4. Build

Code-only changes reuse cached dependency layers.

## Security Checklist

- **Non-root user**: always run as non-root (UID 65532 standard)
- **Pin versions**: never `:latest` — pin base image versions + digests
- **No secrets in layers**: use `--mount=type=secret`, not ARG/ENV
- **Minimal runtime**: no shells, package managers, or unnecessary tools
- **Scan for vulnerabilities**: run image scanning in CI

## .dockerignore

Exclude: `.git`, docs, tests, IDE files, `.env`, build artifacts, `node_modules`/`vendor`, Dockerfile itself.

## Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app", "healthcheck"]
```

## Build Metadata

Use OCI labels and build args for version, commit, build date. Enables traceability from running container back to source.

## Image Size Targets

| Application Type | Target Size |
|-----------------|-------------|
| Static binary (Go, Rust) | <20MB |
| Node.js | <150MB |
| Python | <200MB |
| Java | <250MB |

If significantly over target, investigate unnecessary dependencies or wrong base image.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "Just use :latest" | Unpinned images break reproducibility. Pin versions + digests. |
| "Root is easier" | Root in containers = privilege escalation risk. Always non-root. |
| "One stage is simpler" | Single-stage ships the entire SDK. Multi-stage shrinks 90-95%. |
| "Security scanning is overkill" | Known CVEs in base images are free attack surface. Scan in CI. |

## Red Flags

- `:latest` or unpinned base image tags
- Running as root
- Secrets in ARG/ENV (persisted in layer history)
- Single-stage build shipping SDK/toolchain to production
- No .dockerignore (sending entire repo as build context)
- No HEALTHCHECK defined
- Image significantly over size target

## Verification

- [ ] Multi-stage build (separate build and runtime stages)
- [ ] Non-root user configured
- [ ] Base image versions pinned (not :latest)
- [ ] No secrets in layer history
- [ ] .dockerignore present and excludes unnecessary files
- [ ] HEALTHCHECK defined
- [ ] Image size within target for application type
