# Extending the Framework

How to add new skills, language tiers, agents, or slash commands to your own install.

Every change should end with `hooks/validate-all.sh` passing. The validators enforce plumbing integrity so you cannot silently break cross-references.

## Before you start

1. Read [skill-anatomy.md](skill-anatomy.md) for the required structure of a skill file.
2. Read [architecture.md](architecture.md) for how skills, agents, commands, and hooks fit together.
3. Run `hooks/validate-all.sh` to confirm the repo is in a clean state before you begin.

## Add a new core skill

Core skills are language-agnostic workflow skills. They live in `skills/core/<name>/SKILL.md`.

1. **Create the directory and file:**
   ```bash
   mkdir -p skills/core/my-new-skill
   touch skills/core/my-new-skill/SKILL.md
   ```
2. **Write the SKILL.md** following the anatomy in [skill-anatomy.md](skill-anatomy.md). Required sections:
   - YAML frontmatter with `name:` and `description:` (pushy — include specific trigger phrases)
   - `## When to Use` — concrete scenarios, not abstract categories
   - `## When NOT to Use` — explicit exclusions
   - `## Core Process` — step-by-step methodology
   - `## Common Rationalizations` — table of shortcuts with domain-specific rebuttals
   - `## Red Flags` — observable indicators of misapplication
   - `## Verification` — checklist of objectively-testable exit criteria
3. **Run the anatomy validator:**
   ```bash
   hooks/validate-skill-anatomy.sh
   ```
   Must pass before you continue.
4. **Register in the marketplace.** Open `.claude-plugin/marketplace.json` and add the path under the `core-skills` plugin's `skills` array — alphabetically. Do this **after** the SKILL.md file exists (the marketplace is strict-mode; missing paths break the whole plugin install).
5. **Wire into one or more agents.** Open the relevant `agents/<name>.md` file and add `- core/my-new-skill` to the `skills:` frontmatter list. Keep the list alphabetical.
6. **Update the routing tree.** Open `skills/core/skill-discovery/SKILL.md` and add a decision-tree branch that routes relevant tasks to your new skill.
7. **Update the catalog.** Add your skill to the appropriate phase section in [skills-catalog.md](skills-catalog.md) with a one-line purpose.
8. **Run all validators:**
   ```bash
   hooks/validate-all.sh
   ```
   All four must pass.

## Add a new language tier

Language tiers extend core skills with implementation patterns for a specific language. Currently only Go is supported.

1. **Create the directory:**
   ```bash
   mkdir -p skills/python
   ```
2. **Write language-specific skills.** Each SKILL.md extends a core counterpart with code patterns, anti-patterns, and language-specific verification. Language skills use a lighter anatomy — see `skills/go/*/SKILL.md` for examples. They do not need the full 5-section core anatomy.
3. **Register as a new plugin group.** Add to `.claude-plugin/marketplace.json`:
   ```json
   {
     "name": "python-skills",
     "description": "Python-specific implementation patterns for ...",
     "source": "./",
     "strict": true,
     "skills": [
       "./skills/python/error-handling",
       "./skills/python/testing"
     ]
   }
   ```
4. **Update session-start detection.** Open `hooks/session-start.sh` and add marker-file detection for the new language. Use the existing patterns (go.mod, package.json, Cargo.toml) as templates.
5. **Update each agent's `## Language-Specific Skills` section.** For every agent in `agents/*.md`, add a new line mapping the language name to the skill list that agent should load. Example:
   ```markdown
   - **python** → `python/error-handling`, `python/testing`, `python/style`
   ```
6. **Update [skills-catalog.md](skills-catalog.md)** with the new tier's skills.
7. **Run all validators.**

## Add a new agent

Agents are specialist roles spawned by slash commands.

1. **Create the agent file:**
   ```bash
   touch agents/my-agent.md
   ```
2. **Write the frontmatter:**
   ```yaml
   ---
   name: my-agent
   description: >
     One-line role description. Use when [specific scenario].
   tools: Read, Grep, Glob, Bash
   model: inherit
   skills:
     - core/style
     - core/token-efficiency
   memory: project
   ---
   ```
3. **Write the body.** Include: Communication Rules, Language-Specific Skills section (map languages to skill lists if the agent loads any), What You Do, How You Work, Output Format (reference [agent-reporting.md](agent-reporting.md)), Process Rules, What You Do NOT Do.
4. **Add an External Side Effects guard** if the agent could run `git push`, `gh pr create`, `docker push`, or any other external-write command. Copy the pattern from `agents/builder.md` or `agents/shipper.md`. See [ops-skills.md](ops-skills.md) for the policy.
5. **Wire into a slash command** that should spawn it. Open the relevant `.claude/commands/<name>.md` and update the "Spawn the `...` agent" line.
6. **Update [agents.md](agents.md)** with a new section for your agent.
7. **Update the skill-discovery decision tree** if the agent handles a new task category.
8. **Run all validators.** The `validate-skill-references.sh` script confirms your agent's `skills:` list resolves. The `validate-agents.sh` script confirms any command that spawns you can find your agent by name.

## Add a new slash command

Slash commands are the entry points for the workflow.

1. **Create the command file:**
   ```bash
   touch .claude/commands/my-command.md
   ```
2. **Write the frontmatter and body:**
   ```markdown
   ---
   description: One-line description of what this command does
   ---

   ## Task

   Spawn the `my-agent` agent with this task: $ARGUMENTS

   Brief workflow notes (3–5 lines).
   ```
3. **Spawn an existing agent by bare name.** Do not use any `{plugin}:{lang}-*` templates. The command file should contain no language-detection logic — that is handled by the session-start hook.
4. **Keep the command file under 25 lines.** Commands are routing documents, not instruction manuals. The agent owns the workflow details.
5. **Update [commands.md](commands.md)** with a new section.
6. **Run the validator:**
   ```bash
   hooks/validate-agents.sh
   ```
   This confirms the agent name in your command file resolves to a real agent.

## Style rules for new skill content

Skills are parsed by agents at runtime. The writing style matters.

- **Imperative form.** "Wrap errors with `fmt.Errorf` and `%w`" not "Errors should be wrapped with..."
- **Explain WHY, not just WHAT.** The agent is a smart reader — giving it the reasoning lets it handle edge cases the skill does not enumerate.
- **Avoid ALL-CAPS MUST/NEVER** where softer reasoning works. Reserve it for genuine hard rules (security, data loss, irreversible actions).
- **Rationalizations table** must be domain-specific. Generic items ("We don't have time") are weak. Specific items ("We'll add auth later — it's internal for now") are strong.
- **Red Flags** should be observable patterns, not abstract principles. "Handler with no input validation" beats "security issues".
- **Verification** items must be objectively checkable. "All tests pass" beats "code is high quality".

## Validation workflow

Run `hooks/validate-all.sh` before any commit that touches skills, agents, commands, or the marketplace. The four validators check:

| Validator | Checks |
|---|---|
| `validate-marketplace.sh` | Every skill path in `marketplace.json` has a `SKILL.md` |
| `validate-skill-anatomy.sh` | Every core/ops skill has the 5 required sections |
| `validate-skill-references.sh` | Every agent's `skills:` list resolves |
| `validate-agents.sh` | Every command's agent reference resolves, no leftover template strings |

If any fails, fix the underlying issue — do not bypass. See [hooks.md](hooks.md) for per-validator troubleshooting.
