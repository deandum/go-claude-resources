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
go work init ./api ./worker ./shared  # Creates go.work
go work sync                          # Sync go.mod files
```

**Never commit `go.work` or `go.work.sum`.** Add both to `.gitignore`. Workspace mode is a local development convenience for multi-module repos — it lets you edit a dependency and see the change immediately in the dependents without a `replace` directive. But CI must build each module from its own `go.mod` + `go.sum`, not through `go.work`, otherwise the build becomes non-reproducible (results depend on which sibling modules happen to be present at build time).

## Vulnerability Scanning

```bash
govulncheck ./...  # Run before releases and in CI
```

`go get` modifies go.mod. `go install` installs binaries without touching go.mod.

## CI Validation

Two checks CI should enforce on every PR:

```bash
# Fail if go.mod or go.sum would be modified by `go mod tidy`
go mod tidy -diff || {
  echo "go.mod or go.sum out of sync — run 'go mod tidy' locally and commit" >&2
  exit 1
}

# Fail on known vulnerabilities in the current dependency graph
govulncheck ./...
```

The `tidy -diff` check catches the common failure mode where a developer adds an import but forgets to run `go mod tidy`, leaving `go.sum` out of sync. The govulncheck catches transitive-dep CVEs that only surface when the graph is walked.

## Versioning Strategy

| Scenario | Action |
|---|---|
| Bug fix | Patch: v1.2.3 -> v1.2.4 |
| New feature (backward compat) | Minor: v1.2.3 -> v1.3.0 |
| Breaking change | Major: v1.2.3 -> v2.0.0 |

## Anti-Patterns

- **Not committing `go.sum`** — always commit both `go.mod` and `go.sum`; `go.sum` is what makes builds reproducible
- **`replace` in production** — remove before releasing; a `replace` pointing to a fork or a local path breaks downstream consumers
- **Skipping `go mod tidy`** — run after every dependency change; CI should enforce this via `go mod tidy -diff`
- **Blindly using `@latest`** — `go get foo@latest` resolves at that moment; six months later a different version ships, your build changes, and nobody knows why. Pin to an exact version (`go get foo@v1.2.3`) and bump deliberately.
- **Committing `go.work`** — workspace mode is local-only; committing it makes CI builds non-reproducible
- **Forgetting `govulncheck` before release** — vulnerabilities in transitive deps are the common case; scan every release build

## Verification

- [ ] `go mod tidy -diff` produces no output (module files already clean)
- [ ] `go.sum` is committed alongside `go.mod`
- [ ] `go.work` and `go.work.sum` are in `.gitignore` (never committed)
- [ ] No `replace` directives in `go.mod` for production builds
- [ ] All dependencies pinned to exact versions (no `@latest`)
- [ ] `govulncheck ./...` passes with no known vulnerabilities
- [ ] CI enforces both `go mod tidy -diff` and `govulncheck` on every PR
