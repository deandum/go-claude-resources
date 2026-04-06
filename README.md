# claude-resources

Multi-language Claude Code agents and skills for production-grade development. Two-tier architecture: **core skills** (language-agnostic workflows) + **language skills** (implementation patterns). Currently supports Go, with Angular and other languages planned.

## Architecture

```
skills/
├── core/          # Language-agnostic: workflows, decision frameworks, verification gates
└── go/            # Go-specific: code patterns, tool configs, framework usage
    # angular/     # (planned)
    # node/        # (planned)
```

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/define` | Analyze task requirements, generate structured spec |
| `/plan` | Design architecture and project structure |
| `/build` | Implement application code following patterns |
| `/test` | Write and run tests |
| `/review` | Code review across five axes |
| `/ship` | Containerize and add observability |
| `/orchestrate` | Decompose complex task, delegate to agents |

## Agents

| Agent | Role |
|-------|------|
| **critic** | Challenges vague requirements. ALWAYS runs first. |
| **lead** | Produces structured specs, delegates to team |
| **architect** | Package layout, interfaces, API surfaces |
| **builder** | Application code following established patterns |
| **cli-builder** | CLI commands, flags, config handling |
| **tester** | Tests, mocks, coverage strategy |
| **reviewer** | Five-axis code review (read-only) |
| **shipper** | Docker, logging, metrics, health checks |

All agents auto-detect project language and load appropriate skills.

## Skills

### Core (11 language-agnostic workflow skills)

`spec-generation` · `skill-discovery` · `error-handling` · `testing` · `code-review` · `api-design` · `concurrency` · `observability` · `docker` · `project-structure` · `style`

Every core skill follows a standard anatomy: When to Use, Core Process, Decision Frameworks, Common Rationalizations, Red Flags, and Verification.

### Go (15 implementation skills)

`error-handling` · `testing` · `testing-with-framework` · `concurrency` · `context` · `database` · `interface-design` · `modules` · `style` · `cli` · `api-design` · `observability` · `docker` · `project-init` · `code-review`

## Spec-Driven Workflow

The lead agent produces structured **SPEC files** that other agents consume directly:

1. `/define` → critic clarifies → lead generates `SPEC-[task].md`
2. Spec includes: Objective, Assumptions, Scope, Subtasks (in waves), Commands, Boundaries, Success Criteria
3. User approves spec → lead executes waves → agents consume spec as prompt
4. Verify against spec's success criteria

## Operational Learning

Session hooks capture project-specific learnings:
- Agents log quirks, conventions, and gotchas during work
- Learnings stored per-project in `~/.claude-resources/learnings/`
- Next session injects recent learnings automatically
- Prevents re-discovery of known patterns

## Recommended Tools

| Tool | Purpose | Install |
|------|---------|---------|
| **LSP** (native) | Go-to-definition, references (~50ms) | `ENABLE_LSP_TOOL=true` + plugins |
| **ast-grep** | Structural code search (AST patterns) | `npm i @ast-grep/cli -g` |
| **Codebase-Memory-MCP** | Knowledge graph for large codebases | [repo](https://github.com/DeusData/codebase-memory-mcp) |

## Adding a New Language

1. Create `skills/<lang>/` with language-specific skill directories
2. Each skill extends a core skill with implementation patterns
3. Add `## Verification` with tool-level checklist items
4. Update `marketplace.json` to register the new skill group
5. Update `hooks/session-start.sh` to detect the new language

## License

MIT
