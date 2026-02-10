---
name: go-modules
description: >
  Go modules dependency management: versioning, go.mod/go.sum, replace directives,
  vendoring, and workspace mode. Use when managing dependencies, updating packages,
  configuring private modules with GOPRIVATE, or troubleshooting module issues.
---

# Go Modules

Minimal version selection. Semantic import versioning. Reproducible builds.

## Contents

- [Pattern 1: Major Version Suffixes (v2+)](#pattern-1-major-version-suffixes-v2)
- [Pattern 2: Replace Directive for Local Development](#pattern-2-replace-directive-for-local-development)
- [Decision Framework: Vendoring vs No Vendoring](#decision-framework-vendoring-vs-no-vendoring)
- [Pattern 3: Private Modules (GOPRIVATE)](#pattern-3-private-modules-goprivate)
- [Pattern 4: Workspace Mode](#pattern-4-workspace-mode)
- [Pattern 5: Vulnerability Scanning](#pattern-5-vulnerability-scanning)
- [Module Retraction](#module-retraction)
- [Decision Framework: Module Versioning Strategy](#decision-framework-module-versioning-strategy)
- [Anti-Patterns](#anti-patterns)

## Pattern 1: Major Version Suffixes (v2+)

Major versions v2+ must include version in module path.

```go
// go.mod for v2
module github.com/yourorg/project/v2  // /v2 suffix required

go 1.24

require (
	github.com/external/pkg/v3 v3.1.0  // v3 import path
)
```

**Import in code:**
```go
import (
	"github.com/yourorg/project/v2/pkg"  // v2 in import path
	"github.com/external/pkg/v3"         // v3 in import path
)
```

**Rules:**
- v0 and v1: No version suffix in import path
- v2+: Must include `/v2`, `/v3`, etc. in module path
- Allows multiple major versions in same project
- Breaking change? Increment major version and update import paths

## Pattern 2: Replace Directive for Local Development

Override dependencies with local copies or forks.

```go
// go.mod
module github.com/yourorg/api

replace (
	// Local development (relative or absolute path)
	github.com/yourorg/shared => ../shared
	github.com/yourorg/models => /home/user/dev/models

	// Use fork instead of original
	github.com/original/pkg => github.com/yourfork/pkg v1.2.3

	// Pin to specific commit
	github.com/some/pkg => github.com/some/pkg v0.0.0-20231201120000-abcdef123456
)
```

**Use Cases:**
- Local development across modules
- Testing unreleased changes
- Using forked dependencies
- Working around bugs in upstream

**Rules:**
- Replace is local only (not published)
- Remove replace before releasing
- Use for development, not production (unless necessary)

## Decision Framework: Vendoring vs No Vendoring

| Use Vendoring | No Vendoring (Default) |
|---|---|
| CI/CD without internet access | Standard workflow (recommended) |
| Hermetic builds required | Trust Go module proxy |
| Corporate proxy restrictions | Public repositories |
| Audit all dependency source code | Faster builds (cached) |

**Enable vendoring:**
```bash
go mod vendor           # Create vendor/ directory
go build -mod=vendor    # Build using vendor/
```

## Pattern 3: Private Modules (GOPRIVATE)

Access private repositories without proxy.

```bash
# Set GOPRIVATE for private repos
export GOPRIVATE="github.com/yourorg/*,gitlab.company.com/*"

# Configure Git credentials
git config --global url."https://username:token@github.com/".insteadOf "https://github.com/"

# Or use SSH
git config --global url."git@github.com:".insteadOf "https://github.com/"
```

**go.mod with private dependency:**
```go
module github.com/yourorg/api

require (
	github.com/yourorg/private-lib v1.2.3  // Private repo
)
```

**Rules:**
- Set GOPRIVATE to bypass proxy for private repos
- Configure authentication (HTTPS token or SSH key)
- Private modules won't be cached in public proxy
- Use in CI/CD with secret management

## Pattern 4: Workspace Mode

Develop multiple modules together in monorepo.

```bash
# Create workspace
go work init ./api ./worker ./shared

# Generates go.work file
cat go.work
```

**go.work file:**
```go
go 1.24

use (
	./api
	./worker
	./shared
)

replace (
	// Optional: workspace-wide replaces
)
```

**Rules:**
- go.work is for local development only (don't commit)
- Automatically uses local versions of modules in workspace
- Eliminates need for replace directives
- Run `go work sync` to sync go.mod files

## Pattern 5: Vulnerability Scanning

```bash
govulncheck ./...
```

Always run `govulncheck` before releases and in CI. Update vulnerable packages with `go get -u <pkg>` followed by `go mod tidy`.

**Key distinction:** `go get` modifies go.mod (add/update dependencies). `go install` installs binary tools without modifying go.mod.

## Module Retraction

Mark versions as unsuitable (published but broken).

```go
// go.mod
module github.com/yourorg/pkg

retract (
	v1.5.0 // Accidentally published
	[v1.1.0, v1.2.0] // Range retraction
)
```

**Effect:**
- go get won't select retracted versions
- Existing users can still use them
- Doesn't delete versions (immutable)
- Use for bugs, security issues, or accidental releases

## Decision Framework: Module Versioning Strategy

| Scenario | Action | Version |
|---|---|---|
| Bug fix (no API changes) | Patch release | v1.2.3 → v1.2.4 |
| New feature (backward compatible) | Minor release | v1.2.3 → v1.3.0 |
| Breaking change | Major release | v1.2.3 → v2.0.0 |
| Pre-release testing | Pre-release tag | v1.3.0-rc.1 |
| Development (unstable) | v0.x.x | v0.2.3 |

**Rules:**
- v0.x.x = unstable, no compatibility guarantees
- v1.0.0+ = stable, semantic versioning applies
- Breaking change = major version increment
- Increment only one component per release

## Anti-Patterns

- **Not committing go.sum** — Always commit both go.mod and go.sum for reproducible builds
- **Replace in production** — Remove all `replace` directives before releasing; use proper versioning
- **Skipping go mod tidy** — Run `go mod tidy` after every dependency change to keep go.mod clean
- **Vendoring by default** — Only vendor when necessary (air-gapped CI, hermetic builds); default to Go module proxy
- **Blindly using @latest** — Pin to major version (`go get pkg@v1`) or exact version to avoid breaking changes
