# claude-resources

Multi-language spec-driven development framework. Core skills (language-agnostic workflows) + language skills (implementation patterns). Currently supports Go.

## Structure

```
skills/
├── core/           # 20 language-agnostic workflow skills (default)
├── go/             # 15 Go implementation skills (default)
└── ops/            # 4 opt-in external-write skills (NOT enabled by default)
agents/             # 9 specialist agents
hooks/              # Session lifecycle + learning system
.claude/commands/   # 10 slash commands
.claude-plugin/     # Plugin manifest + marketplace registry (3 plugin groups)
docs/               # Deep-dive documentation + docs/specs/<slug>/ spec directories
references/         # Cross-cutting reference material
```

**The `ops-skills` plugin** covers remote-write actions (`git push`, `gh pr create`, `docker push`, release publishing) and is intentionally separate. The session-start hook emits `ops_enabled: true/false` based on whether `skills/ops/` is populated; agents read this flag before running any external-write command and report the intended action as a follow-up when disabled.

## Skills by Phase

| Phase | Core Skills |
|-------|-------------|
| Define | idea-refine, discovery, spec-generation, skill-discovery |
| Plan | project-structure, api-design, documentation |
| Build | error-handling, concurrency, style, debugging |
| Test | testing |
| Review | code-review, simplification, security, performance |
| Ship | docker, observability, git-workflow |
| Cross-cutting | token-efficiency |

## Conventions

### Skill anatomy
Every core skill has YAML frontmatter (`name`, `description`) and follows: When to Use, When NOT to Use, Core Process, Common Rationalizations, Red Flags, Verification. See [docs/extending.md](docs/extending.md#skill-anatomy) for the full reference.

### Naming
- Skill dirs: `lowercase-kebab-case`
- Each skill: one `SKILL.md` file
- Core skills: no supporting files unless content exceeds ~100 lines. `core/spec-generation/references/` is an accepted exception — it ships four spec-directory templates (spec, discovery, critique, group-log) that lead copies into `docs/specs/<slug>/` on every `/define` invocation.
- Language skills: may have `references/` and `templates/` subdirs

### Frontmatter

```yaml
# Skills
---
name: skill-name
description: >
  What it does. When to use it.
---

# Agents
---
name: agent-name
description: Role description.
tools: Read, Grep, Glob, ...
model: inherit
skills:
  - core/skill-name
memory: project
---

# Slash commands
---
description: What this command does
---
```

### JSON
2-space indentation. No tabs.

### Cross-References
- Core skills: `core/<skill-name>` (e.g., `core/error-handling`)
- Language skills: `<lang>/<skill-name>` (e.g., `go/testing`)
- Agents: `agents/<name>` (e.g., `agents/builder`)
- Docs: relative links (e.g., `[Getting Started](docs/getting-started.md)`)
- In skill files, use "Pair with" to suggest related skills

## Quality Criteria

Every skill, agent, or command must meet these four standards:

1. **Specific** — Actionable steps, not general guidance. "Wrap errors with fmt.Errorf and %w" not "handle errors properly."
2. **Verifiable** — Clear completion criteria with observable evidence. Every skill ends with a verification checklist.
3. **Battle-tested** — From actual engineering practice, not theory. If you haven't used it in production, it doesn't belong here.
4. **Minimal** — Only essential information for agent guidance. Three lines of clarity beat a page of completeness.

## Agent Guidance

- Skills are loaded on-demand based on language detection, not all at once
- Respect context window limits — load only skills relevant to the current task
- Agents should record non-obvious project discoveries via `hooks/learn.sh`
- Each agent has a single, well-bounded role — do not expand scope
- All agents apply `core/token-efficiency` by default — compress human-facing output, never specs or agent-to-agent artifacts

## Boundaries

### Always
- Keep core skills language-agnostic (no Go/Python/Rust code or conventions)
- Follow existing frontmatter format
- Register new skills in marketplace.json
- Update skill-discovery routing for new skills
- Update README skill counts and lists

### Ask first
- Adding new language tiers (e.g., `skills/python/`)
- Changing skill-discovery routing logic
- Modifying hook behavior
- Adding new agents

### Never
- Add language-specific code/paths to core skills
- Break existing frontmatter contracts
- Add supporting files to core skills without justification
- Remove skills without updating all cross-references

## Adding a Language

1. Create `skills/<lang>/` with language-specific skill directories
2. Each skill extends a core skill with implementation patterns
3. Add `## Verification` with tool-level checklist items
4. Register in `marketplace.json` as a new plugin group
5. Update `hooks/session-start.sh` to detect the new language
6. Add the new language to each agent's `## Language-Specific Skills` section (mapping the language to the skill list that agent loads)

## Adding a Skill

1. Create `skills/<tier>/<skill-name>/SKILL.md`
2. Follow the standard anatomy (see [Skill Anatomy](docs/extending.md#skill-anatomy))
3. Register in `marketplace.json` under the correct plugin group
4. Update `skills/core/skill-discovery/SKILL.md` decision tree
5. Update `README.md` skill list and count
6. If user-invocable: create `.claude/commands/<name>.md`
