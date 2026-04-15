---
name: go/interface-design
description: >
  Go interface patterns. Accept interfaces/return structs, consumer-side
  definition, interface segregation, generics vs interfaces. 100% Go-specific.
---

# Go Interface Design

The bigger the interface, the weaker the abstraction.

## Should This Be an Interface?

Don't create interfaces until needed. Interfaces should be discovered, not designed upfront.

- Multiple implementations NOW? No -> don't create yet (YAGNI)
- Consumers need to swap implementations? No -> concrete type
- Can define 1-3 methods? Yes -> create at consumer side

## Accept Interfaces, Return Concrete Types

```go
// Interface at consumer side
type Repository interface {
    FindByID(ctx context.Context, id int64) (*User, error)
    Save(ctx context.Context, user *User) error
}

// Function accepts interface, returns concrete
func GetUserProfile(ctx context.Context, repo Repository, id int64) (*User, error) {
    return repo.FindByID(ctx, id)
}
```

## Interface Segregation

```go
// Small, focused interfaces
type UserFinder interface { FindByID(ctx context.Context, id int64) (*User, error) }
type UserCreator interface { Create(ctx context.Context, user *User) error }

// Compose when needed
type UserRepository interface { UserFinder; UserCreator }
```

Ideal: 1-3 methods. Questionable: 5+.

## Compile-Time Verification

```go
var _ Storage = (*FileStorage)(nil)
```

## Generics vs Interface vs Concrete

| Interface | Generics | Concrete |
|---|---|---|
| Multiple impls exist | Type-safe containers | Single implementation |
| Behavior abstraction | Algorithms across types | No abstraction needed |
| Testing with mocks | Collections (slice/map) | Simplicity preferred |

Default to concrete. Add interface when testing or multiple impls needed.

## Stdlib Interfaces

Accept `io.Reader`, `io.Writer`, `io.Closer`, `fmt.Stringer` for maximum compatibility.

## Mock-Friendly Design

Keep interfaces small -> easy to mock. Use function-based mocks (see `go/testing`).

## Naming

- Single-method: `-er` suffix (`Reader`, `Writer`, `Closer`)
- Multi-method: descriptive noun (`UserRepository`)
- No `Interface` suffix

## Verification

- [ ] Interfaces defined at the consumer side, not the implementation package
- [ ] Compile-time interface checks present (`var _ I = (*T)(nil)`)
- [ ] Interfaces have 1-3 methods each (split larger interfaces via composition)
- [ ] Functions accept interfaces and return concrete types
