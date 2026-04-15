# Swagger/OpenAPI Integration

Use go-swagger for automatic API documentation and validation.

## Code-First Approach: Annotate Go Code

```go
// Package classification User API.
//
// Documentation for User API
//
//	Schemes: http, https
//	BasePath: /api/v1
//	Version: 1.0.0
//	Contact: support@example.com
//
//	Consumes:
//	- application/json
//
//	Produces:
//	- application/json
//
// swagger:meta
package api

// swagger:parameters createUser
type CreateUserRequest struct {
	// User data to create
	// in: body
	// required: true
	Body struct {
		// User's full name
		// required: true
		// example: John Doe
		Name string `json:"name"`
		// User's email address
		// required: true
		// example: john@example.com
		Email string `json:"email"`
	}
}

// swagger:response userResponse
type UserResponse struct {
	// in: body
	Body struct {
		ID    int64  `json:"id"`
		Name  string `json:"name"`
		Email string `json:"email"`
	}
}

// swagger:route POST /users users createUser
//
// Create a new user
//
// Creates a new user in the system with the provided details.
//
// responses:
//   201: userResponse
//   400: errorResponse
func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
	// Implementation
}
```

## Generate Swagger Specification

```bash
# Install go-swagger
go install github.com/go-swagger/go-swagger/cmd/swagger@latest

# Generate swagger.json from annotations
swagger generate spec -o ./swagger.json

# Serve Swagger UI
swagger serve -F swagger ./swagger.json
```

**Makefile targets:**
```makefile
.PHONY: swagger
swagger:
	swagger generate spec -o ./swagger.json --scan-models

.PHONY: swagger-serve
swagger-serve: swagger
	swagger serve -F swagger ./swagger.json
```

## Swagger Validation Middleware

Integrate swagger validation with chi router:

```go
import (
	"github.com/go-openapi/loads"
	"github.com/go-openapi/runtime/middleware"
)

func setupSwagger(r chi.Router) error {
	// Load swagger spec
	swaggerSpec, err := loads.Analyzed(SwaggerJSON, "")
	if err != nil {
		return err
	}

	// Serve swagger.json
	r.Get("/swagger.json", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(SwaggerJSON)
	})

	// Serve Swagger UI
	opts := middleware.RedocOpts{SpecURL: "/swagger.json"}
	r.Handle("/docs", middleware.Redoc(opts, nil))

	return nil
}
```

## Decision Framework: Spec-First vs Code-First

| Approach | Spec-First | Code-First (Recommended) |
|---|---|---|
| **Workflow** | Write OpenAPI spec → Generate code | Write Go code → Generate spec |
| **Pros** | Contract-first, language-agnostic | Leverages existing Go code, less duplication |
| **Cons** | Code generation overhead, synchronization | Annotations can be verbose |
| **Best For** | Multi-language teams, strict API contracts | Go-only teams, rapid iteration |

**Recommendation**: Use code-first with go-swagger for Go-centric teams. Use spec-first when API contract must be language-agnostic.
