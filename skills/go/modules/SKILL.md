---
name: go/modules
description: >
  Go modules dependency management. go.mod/go.sum, versioning, replace
  directives, vendoring, private modules, workspaces. 100% Go-specific.
---

# Go Modules

Minimal version selection. Semantic import versioning. Reproducible builds.

## Major Version Suffixes (v2+)

```go
module github.com/yourorg/project/v2  // v2+ requires /vN suffix
require github.com/external/pkg/v3 v3.1.0
```

v0/v1: no suffix. v2+: `/v2` in module path and imports.

## Replace Directive

```go
replace (
    github.com/yourorg/shared => ../shared       // Local dev
    github.com/original/pkg => github.com/fork/pkg v1.2.3  // Fork
)
```

Remove before releasing. Local development only.

## Vendoring

Use vendoring only when: air-gapped CI, hermetic builds required, corporate proxy restrictions. Otherwise use Go module proxy (default).

```bash
go mod vendor && go build -mod=vendor
```

## Private Modules

```bash
export GOPRIVATE="github.com/yourorg/*"
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

## Workspace Mode (Monorepo)

```bash
go work init ./api ./worker ./shared  # Creates go.work (don't commit)
go work sync                          # Sync go.mod files
```

## Vulnerability Scanning

```bash
govulncheck ./...  # Run before releases and in CI
```

`go get` modifies go.mod. `go install` installs binaries without touching go.mod.

## Versioning Strategy

| Scenario | Action |
|---|---|
| Bug fix | Patch: v1.2.3 -> v1.2.4 |
| New feature (backward compat) | Minor: v1.2.3 -> v1.3.0 |
| Breaking change | Major: v1.2.3 -> v2.0.0 |

## Anti-Patterns

- Not committing go.sum — always commit both go.mod and go.sum
- Replace in production — remove before releasing
- Skipping `go mod tidy` — run after every dependency change
- Blindly using @latest — pin versions

## Verification

- [ ] `go mod tidy` produces no changes (module files already clean)
- [ ] `go.sum` is committed alongside `go.mod`
- [ ] No `replace` directives in `go.mod` for production builds
- [ ] `govulncheck ./...` passes with no known vulnerabilities
