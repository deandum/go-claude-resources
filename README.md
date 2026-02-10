# go-claude-resources

A collection of Claude Code agents and skills for Go development. Drop these into your project to get opinionated, consistent AI assistance when building Go services and CLIs.

## What's Inside

### Agents

Reusable agent definitions that follow a structured workflow:

| Agent | Role |
|-------|------|
| **go-critic** | Analyzes prompts for clarity and completeness before work begins |
| **go-architect** | Package layout, interfaces, and API surface design |
| **go-builder** | Application code implementation |
| **go-cli-builder** | CLI implementation with Cobra |
| **go-tester** | Test writing and execution |
| **go-reviewer** | Read-only code review |
| **go-shipper** | Containerization and observability |

### Skills

Topic-specific skills that provide domain knowledge:

`go-style` · `go-project-init` · `go-error-handling` · `go-testing` · `go-testing-with-framework` · `go-concurrency` · `go-code-review` · `go-context` · `go-interface-design` · `go-database` · `go-modules` · `go-cli` · `go-api-design` · `go-observability` · `go-docker`

## Usage

Copy the agents and skills you need into your project's `.claude/` directory, or reference this repo directly in your Claude Code configuration.

## License

MIT
