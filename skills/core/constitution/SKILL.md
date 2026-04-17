---
name: constitution
description: >
  Author and maintain a project constitution at docs/constitution.md — the
  list of invariants that reviewer and critic enforce on every spec and every
  diff. Load this skill whenever you're creating a new constitution from
  scratch or from EXAMPLE_CONSTITUTION.md, proposing candidate invariants via
  /constitution-propose, adding or editing an invariant, sunsetting an
  obsolete rule, or promoting a recurring "don't do X" review comment into an
  enforced invariant. Also use when a post-incident review surfaces a rule
  that should have been caught mechanically. Reviewer and critic consume the
  registered invariants automatically via the project_constitution
  session-start field — you do not need this skill for enforcement, only for
  authoring.
---

# Constitution

A constitution is the list of invariants that must hold across every spec, every group, every review. Skills teach patterns; the constitution enforces outcomes.

## When to Use

- Starting a new project and codifying non-negotiables before the first feature
- A post-incident review reveals a rule that should have been caught mechanically
- A recurring review comment ("don't do X") needs to be promoted from convention to enforcement
- An invariant becomes obsolete and needs to be sunset

## When NOT to Use

- Style nudges — those belong in a linter config or `core/style`
- One-off decisions — those belong in a commit message or ADR
- Nice-to-haves — if you would accept a PR that violates it, it is not an invariant
- Framework-level rules for consumers — those belong in `CLAUDE.md` of the consumer project

## Core Process

1. **Locate or create the constitution.** Consumers: copy `EXAMPLE_CONSTITUTION.md` to `docs/constitution.md`. This framework's own constitution lives at `docs/constitution.md`.
2. **State the invariant.** One paragraph answering: what must be true, and what does a violation look like?
3. **Pick severity honestly.** `critical` = reviewer blocks advancement. `important` = reviewer flags but does not block. If you would accept exceptions, it is `important`.
4. **Narrow the scope.** "All code" is almost never right. State exact paths, packages, or file patterns.
5. **Describe detection concretely.** Reviewer needs a grep-able signal or a specific pattern to match. Vague detection = unenforced invariant.
6. **Register in frontmatter.** Add `{id, severity}` to the YAML `invariants:` list. `hooks/session-start.sh` reads this list and emits `project_constitution` into session context.
7. **Verify enforcement.** Author a deliberate violation in a test branch, run `/review`, confirm reviewer flags it at the expected severity.

## Invariant Anatomy

Every invariant has two parts: a frontmatter entry that agents read from session context, and a body section with the human-readable detail.

**Frontmatter entry** (registered in `docs/constitution.md` YAML):

```yaml
---
title: Project Constitution
invariants:
  - id: no-silent-failures
    severity: critical
  - id: public-function-tested
    severity: important
---
```

**Body section** (one per invariant, six fields):

- **id** — `kebab-case-id`, short, memorable, grep-able in reviewer output. Matches the frontmatter entry.
- **Severity** — `critical` or `important`. No third tier.
- **Enforced by** — which agent owns the check: `reviewer`, `critic`, or both. Reviewer inspects diffs; critic inspects specs. Pick the agent that actually has the relevant context.
- **Scope** — exact files, packages, or patterns where the invariant applies.
- **Rationale** — one paragraph future-you will not forget the reason.
- **Detection** — concrete pattern reviewer can grep or match against.

## Severity

| Level | Reviewer Behavior | Critic Behavior |
|-------|-------------------|-----------------|
| `critical` | Violation forces a Critical finding; status becomes `needs-input`; group cannot advance without explicit user acceptance | Violation becomes a `Blocker: yes` clarifying question — the spec cannot be synthesized as written |
| `important` | Violation contributes to Important findings; status becomes `needs-input`; user must accept before advance | Violation becomes a suggested scope hazard to fold into `Out of Scope` or `Ask first` |

## Proposing Candidates

Authoring an initial constitution from a blank page is the hard case. Running `/constitution-propose` has main Claude spawn `critic` + `scout` in parallel to survey the codebase and propose 3–10 candidate invariants grounded in concrete evidence. The user then accepts, edits, or rejects each one. This section is the discipline the agents apply.

**Trigger**: `/constitution-propose [optional focus]`. Focus narrows the survey to one area (`security`, `observability`, `error handling`, …). Empty = full checklist.

**Directory**: `docs/specs/constitution-proposal/` — a reserved, non-feature slug. Only two files live there: `discovery.md` (scout) and `candidates.md` (critic). **No `spec.md`** — this is not spec generation, and session-start's active-spec scanner requires a `spec.md` to include a slug in `active_specs`, so this directory is correctly ignored.

**Scout's brief** — survey the codebase per the checklist below and write `docs/specs/constitution-proposal/discovery.md`. Every claim cites `file:line`. If `$ARGUMENTS` is non-empty, narrow the checklist to that focus only.

Discovery checklist (language-conditional):

- *Error handling* — Go: `_ = err`, `panic(`, `return nil` after a non-nil err check. Python: bare `except:`, `pass` inside an except block. JS/TS: empty `catch {}`, unawaited promises inside async callers.
- *Secret-like patterns* — literal `api_key`, `password`, `TOKEN=`, `BEGIN RSA PRIVATE KEY`, hardcoded bearer tokens. `.env` referenced with no committed `.env.example`.
- *Test coverage gaps* — exported/public functions in `internal/`, `pkg/`, or the language equivalent with no matching test file.
- *Boundary files* — HTTP handler files, DB migration directories, external API client packages. Catalogue paths; invariants typically bite here.
- *Observability* — log call density, error-wrapping style (`%w` vs `%s`, wrapped vs swallowed), presence or absence of correlation-id plumbing across request boundaries.

**Critic's brief** — read scout's `discovery.md`, apply the quality bar below, propose 3–10 candidates. Write `docs/specs/constitution-proposal/candidates.md`.

Candidate quality bar (reject anything that fails all of these):

- Cites at least one `file:line` of evidence from scout's discovery.
- Has a grep-able `Detection` clause — not "reviewer judges."
- Is not a style nudge (formatting, naming) — those belong in a linter.
- Is not a nice-to-have — if reviewer would merge a PR that violates it, it is not an invariant.
- Is not already covered by `project_constitution` — note existing invariants in `candidates.md` as "already invariant" rather than re-proposing.
- Is not already in `candidates.md` with `status: rejected` from a prior run — a rejection is permanent until the user clears it.

**Candidate file format** — YAML frontmatter mirroring `EXAMPLE_CONSTITUTION.md` plus a per-invariant `status` field, and body sections that add `Evidence:` and `Status:` on top of the standard six-field anatomy:

```markdown
---
title: Constitution Candidates
generated: 2026-04-16
candidates:
  - id: no-silent-failures
    severity: critical
    status: proposed
---

## no-silent-failures
- **Severity**: critical
- **Enforced by**: reviewer
- **Scope**: all code under `internal/` and `cmd/`
- **Rationale**: A caught error that is not logged, wrapped, or returned becomes invisible in prod.
- **Detection**: `_ = err`, `return nil` after a non-nil err check, `catch {}` without body.
- **Evidence**: `internal/ingest/worker.go:142`, `cmd/api/handler.go:88`
- **Status**: proposed
```

**User review protocol** — main Claude prints the candidate summary, then waits for a reply of the form:

```
accept: [id1, id2, ...]
edit:   <id>: <new-rationale-or-detection>
reject: [id3, ...]
stop
```

Main Claude mutates the `status:` field in `candidates.md` for every reviewed candidate (`accepted` / `edited` / `rejected`) so re-runs can skip them.

**Promotion rule** — on `accept` or `edit`, main Claude appends the accepted body section to `docs/constitution.md` AND adds the `{id, severity}` entry to the frontmatter `invariants:` list. If `docs/constitution.md` does not exist, main Claude creates it first using the frontmatter and heading shape from `EXAMPLE_CONSTITUTION.md`. Rejected candidates stay in `candidates.md` with `status: rejected` — the record prevents re-proposal on the next run.

## Pair With

- `core/code-review` — reviewer loads the constitution as a sixth check after the five axes
- `core/spec-generation` — main Claude mirrors `critical` invariants into the spec's `Never do` tier verbatim during spec synthesis
- `core/skill-discovery` — routes "authoring or modifying project invariants" to this skill

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "Everyone knows this rule; no need to codify" | Unwritten rules are only enforced by whoever remembers them. Reviewer and critic have no memory between sessions. |
| "Style nits should be here too" | Mixing invariants with style creates noise. Reviewers stop reading long lists. Lint the style; constitutionalize the invariants. |
| "Severity doesn't matter, I'll mark everything critical" | Reviewer blocks every PR on every item. Authors route around by marking as "exception." Severity loses meaning. |
| "We can leave obsolete invariants in place; they just won't fire" | Dead rules poison the list — readers treat active rules with the same scrutiny as inactive ones. Sunset or delete. |

## Red Flags

- Invariant list exceeds 10 items — probably conflating invariants with conventions
- `Scope: all code` on most invariants — suggests the rule is actually narrower
- No `Detection` clause, or detection is "reviewer judges" — reviewer has no reliable signal
- An invariant that has never caught a violation in practice — either wrongly scoped or unneeded
- `critical` severity on more than half the list — severity is no longer discriminating

## Verification

- [ ] `docs/constitution.md` exists at project root
- [ ] YAML frontmatter contains `title:` and `invariants:` list with `{id, severity}` per item
- [ ] Each invariant has all five body fields: Severity, Enforced by, Scope, Rationale, Detection
- [ ] `hooks/session-start.sh` emits `project_constitution` field when the file is present
- [ ] Reviewer flags a deliberate violation at the expected severity
- [ ] Total invariant count is between 3 and 10
