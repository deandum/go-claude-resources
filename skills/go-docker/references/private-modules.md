# Private Go Modules Without Exposing Secrets

Use Docker secrets or SSH for private module access without leaking credentials.

## Contents

- [Option 1: SSH Agent Forwarding (Recommended)](#option-1-ssh-agent-forwarding-recommended)
- [Option 2: Build-Time Secrets (Docker BuildKit)](#option-2-build-time-secrets-docker-buildkit)
- [Option 3: Netrc for HTTPS Authentication](#option-3-netrc-for-https-authentication)
- [Decision Framework: GOPRIVATE Authentication Method](#decision-framework-goprivate-authentication-method)

## Option 1: SSH Agent Forwarding (Recommended)

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.24-alpine AS builder

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

## Option 2: Build-Time Secrets (Docker BuildKit)

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.24-alpine AS builder

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

## Option 3: Netrc for HTTPS Authentication

```dockerfile
FROM golang:1.24-alpine AS builder

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
