---
name: go-modules
description: >
  Go modules dependency management: versioning, go.mod/go.sum, replace directives,
  vendoring, and workspace mode. Use when managing dependencies, updating packages,
  or troubleshooting module issues.
---

# Go Modules

Minimal version selection. Semantic import versioning. Reproducible builds.

## When to Apply

Use this skill when:
- Initializing new Go projects (`go mod init`)
- Adding, updating, or removing dependencies
- Resolving version conflicts or import cycles
- Working with private repositories or monorepos
- Reviewing go.mod or go.sum changes in PRs
- Setting up vendoring or workspace mode

## go.mod Structure

The `go.mod` file defines your module and its dependencies.

```go
module github.com/yourorg/yourproject

go 1.21 // Minimum Go version required

require (
	github.com/gin-gonic/gin v1.9.1
	github.com/jmoiron/sqlx v1.3.5
	golang.org/x/sync v0.5.0
)

require (
	// Indirect dependencies (transitive)
	github.com/bytedance/sonic v1.10.2 // indirect
	github.com/golang/protobuf v1.5.3 // indirect
)

replace (
	// Replace for local development
	github.com/yourorg/shared => ../shared
)

exclude (
	// Exclude known broken versions
	github.com/some/pkg v1.2.3
)
```

**Sections:**
- `module`: Module path (matches import path)
- `go`: Minimum Go version
- `require`: Direct and indirect dependencies
- `replace`: Override dependencies (local paths or forks)
- `exclude`: Ban specific versions

## Pattern 1: Initialize and Add Dependencies

```bash
# Initialize new module
go mod init github.com/yourorg/project

# Add dependency (automatically updates go.mod)
go get github.com/gin-gonic/gin@latest
go get github.com/gin-gonic/gin@v1.9.1  # Specific version
go get github.com/gin-gonic/gin@v1.9    # Latest patch of v1.9.x

# Add dependency without updating go.mod
go install github.com/swaggo/swag/cmd/swag@latest

# Remove unused dependencies
go mod tidy

# Download all dependencies
go mod download
```

**Rules:**
- Use `go get` to add/update dependencies and modify go.mod
- Use `go install` for installing binaries (doesn't modify go.mod)
- Run `go mod tidy` regularly to remove unused deps
- Commit both go.mod and go.sum to version control

## Pattern 2: Semantic Versioning

Go modules use semantic versioning: `vMAJOR.MINOR.PATCH`.

```bash
# Patch update (bug fixes, backward compatible)
v1.2.3 → v1.2.4

# Minor update (new features, backward compatible)
v1.2.3 → v1.3.0

# Major update (breaking changes, NOT backward compatible)
v1.2.3 → v2.0.0
```

**Version Ranges:**
```bash
@latest         # Latest version (including pre-releases if no releases exist)
@v1.2.3         # Exact version
@v1.2           # Latest v1.2.x patch
@v1             # Latest v1.x.x minor/patch
@upgrade        # Latest compatible version (respects go.mod constraints)
@patch          # Latest patch version only
```

## Pattern 3: Major Version Suffixes (v2+)

Major versions v2+ must include version in module path.

```go
// go.mod for v2
module github.com/yourorg/project/v2  // /v2 suffix required

go 1.21

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

## Pattern 4: Replace Directive for Local Development

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

## Pattern 5: Private Modules (GOPRIVATE)

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

## Pattern 6: Workspace Mode (Go 1.18+)

Develop multiple modules together in monorepo.

```bash
# Create workspace
go work init ./api ./worker ./shared

# Generates go.work file
cat go.work
```

**go.work file:**
```go
go 1.21

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

## Pattern 7: Dependency Updates

```bash
# Update all dependencies to latest compatible versions
go get -u ./...

# Update only patch versions
go get -u=patch ./...

# Update specific package
go get -u github.com/gin-gonic/gin

# View available updates
go list -u -m all

# Check for outdated dependencies
go list -u -m all | grep '\['
```

**Security updates:**
```bash
# Scan for vulnerabilities
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...

# Update vulnerable packages
go get -u github.com/vulnerable/pkg
go mod tidy
```

## Pattern 8: go get vs go install

| Command | Purpose | Modifies go.mod |
|---|---|---|
| `go get pkg@version` | Add/update dependency | Yes |
| `go install pkg@version` | Install binary tool | No |
| `go get -u ./...` | Update all deps | Yes |
| `go install ./cmd/app` | Build and install local binary | No |

**Examples:**
```bash
# Add dependency to project
go get github.com/gin-gonic/gin@latest

# Install tool (doesn't affect go.mod)
go install github.com/swaggo/swag/cmd/swag@latest
go install golang.org/x/tools/cmd/goimports@latest
```

## Minimal Version Selection (MVS)

Go uses MVS algorithm: select the minimum required version that satisfies all constraints.

**Example:**
```
Project requires:     A v1.2.0
Dependency X requires: A v1.3.0
Dependency Y requires: A v1.1.0

MVS selects: A v1.3.0  (minimum version that satisfies all)
```

**Benefits:**
- Reproducible builds
- Predictable upgrades
- No "dependency hell"
- Conservative version selection

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

### Not committing go.sum

```bash
# BAD: .gitignore includes go.sum
echo "go.sum" >> .gitignore

# GOOD: Always commit go.sum
git add go.mod go.sum
git commit -m "Update dependencies"
```

### Using replace in production

```go
// BAD: Replace in production code
replace github.com/pkg/lib => ../local-lib

// GOOD: Remove replace before releasing
// Use proper versioning instead
```

### Ignoring go mod tidy

```bash
# BAD: Never running tidy (bloated go.mod)
go get github.com/new/pkg

# GOOD: Clean up unused deps
go get github.com/new/pkg
go mod tidy
```

### Vendoring without necessity

```bash
# BAD: Vendoring by default (2x storage, slower git)
go mod vendor
git add vendor/

# GOOD: Use vendoring only when necessary
# Default: rely on Go module proxy
```

### Blindly using @latest

```bash
# BAD: Breaking changes from @latest
go get github.com/pkg/lib@latest  # Could be v2, v3, breaking!

# GOOD: Pin to major version
go get github.com/pkg/lib@v1      # Latest v1.x.x
go get github.com/pkg/lib@v1.2.3  # Exact version
```

## Troubleshooting Common Issues

**Issue: "module not found"**
```bash
# Solution: Update module cache
go clean -modcache
go mod download
```

**Issue: "checksum mismatch"**
```bash
# Solution: Verify and update go.sum
go mod verify
go get -u github.com/pkg/name
go mod tidy
```

**Issue: Import cycle**
```bash
# Solution: Refactor to break cycle
# Move shared types to separate package
```

## go.sum File

The `go.sum` file contains checksums for reproducible builds.

```
github.com/gin-gonic/gin v1.9.1 h1:abc123...
github.com/gin-gonic/gin v1.9.1/go.mod h1:def456...
```

**Rules:**
- Generated automatically by go commands
- **Always commit go.sum** to version control
- Ensures dependencies haven't been tampered with
- Used to verify downloads match expected checksums
- Don't edit manually

## References

- [Go Modules Reference](https://go.dev/ref/mod)
- [Go Module Tutorial](https://go.dev/doc/tutorial/create-module)
- [Semantic Versioning](https://semver.org/)
