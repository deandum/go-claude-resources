---
name: security
description: >
  Security-by-DESIGN discipline for feature design — threat modeling,
  authz/authn design, secrets management, input validation at
  boundaries, OWASP Top 10 awareness. Use when starting to design
  any feature that handles user input, authentication, authorization,
  stored data (especially PII or credentials), or external I/O.
  Trigger on any task mentioning "auth", "login", "permissions",
  "secrets", "tokens", "user input", "API endpoint", "threat model",
  or "security review". NOT the review-time checklist — that lives
  in `core/code-review` §4. Use this skill BEFORE code exists, to
  prevent issues the checklist would only catch later.
---

# Security

Security is a design discipline, not a review checklist. By the time code is in review, the important security decisions have already been made — or already missed. This skill is the design-time discipline. For the review-time checklist, see `core/code-review` §4 Security.

## When to Use

- Designing or adding any feature that handles user input
- Adding authentication or authorization logic
- Persisting new data (especially PII or credentials)
- Integrating a new external service or API
- Exposing a new endpoint, port, or API surface
- Handling secrets, keys, or tokens

## When NOT to Use

- Pure internal refactors that do not change surface area
- UI-only changes with no data flow or privilege change
- Documentation or tooling changes

## Core Process

### 1. Model the threat surface before writing code

For every new feature, answer:

1. **Who can call this?** Unauthenticated, authenticated, admin, service-to-service — each is a different surface.
2. **What can they pass?** Parameters, bodies, headers, files. Assume every field is adversarial.
3. **What does it touch?** Database, filesystem, external API, secrets vault.
4. **What could go wrong?** One sentence per risk. OWASP Top 10 is a checklist, not a ceiling.

If you cannot answer any of these, you are not ready to implement.

### 2. Validate at the boundary, trust within

The boundary is where the system meets something it does not control — HTTP handlers, CLI arg parsers, message consumers, database rows loaded from external data. At the boundary:

- Reject anything that does not match a strict schema
- Canonicalize (normalize Unicode, trim, lowercase where appropriate)
- Size-limit every field — unbounded inputs are DoS vectors
- Reject unknown fields instead of ignoring them

Inside the boundary, trust the types. Revalidating everywhere is noise that hides the one place where validation was missed.

### 3. Authorization is a decision, not a check

Every protected action answers two questions:

1. **Who is acting?** (authentication — identity)
2. **Are they allowed?** (authorization — permission)

Authentication lives at the edge. Authorization lives at each protected action. Never conflate them. Never infer one from the other.

Design authorization up front:

- What objects exist?
- Who owns each object?
- What actions does each role have?
- Where does the check live — handler, service, both?

Defense in depth: put authorization close to the data. A handler check that is bypassed by a service call is not defense.

### 4. Secrets are not config

Secrets — API keys, DB passwords, signing keys, tokens — are not config:

- Never in source code
- Never in logs
- Never in error messages
- Never in stack traces
- Never in commit history (if they slip in, rotate — do not just `git rebase`)

Secrets come from a secrets manager or environment variables injected at runtime. Always.

### 5. Fail closed, log everything, leak nothing

When authorization fails, return as little information as possible to the caller. "Not found" is often safer than "forbidden" because it does not reveal existence.

When security events happen (failed auth, denied access, rate-limit trip), log them with enough context for forensics — but scrub PII and secrets from the log line itself.

### 6. The OWASP Top 10 is a starting point

Cycle through the current OWASP Top 10 for every new feature. Ask whether the design is vulnerable to each — not whether the code is. Design catches issues the implementation cannot.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "We'll add auth later — it's internal for now." | "Internal for now" is how data breaches start. Design auth in from day one, even if the initial check is permissive. |
| "The frontend validates it, so the API doesn't have to." | The frontend is a suggestion. The API is the contract. Validate at the API. |
| "This secret is only in a config file." | Config files get committed, printed, emailed, left on laptops. Secrets go in a secrets manager. |
| "The threat model is obvious." | If it were obvious, there would be no security incidents. Write it down. |
| "Logging the request body will help debug." | It will also log the user's password when they typo into the email field. Scrub first. |

## Red Flags

- Endpoints with no authorization check
- Authorization that lives only in the UI or frontend
- Secrets in config files, env files, or commit history
- Input parsing that accepts unknown fields or unbounded strings
- Error messages that leak whether a user/object exists
- Stack traces returned to users on error
- SQL or shell commands built from string concatenation
- Logs that include bodies, headers, tokens, or passwords

## Verification

- [ ] Threat model written down for any new surface: callers, inputs, data touched, risks
- [ ] Every new endpoint has an explicit authorization decision
- [ ] All inputs validated at the boundary against a schema with size limits
- [ ] No secrets in source code, config files, logs, or error messages
- [ ] Error responses do not leak existence or stack traces
- [ ] Logged security events scrubbed of PII and credentials
- [ ] OWASP Top 10 walkthrough complete for the new surface
