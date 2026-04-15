---
name: token-efficiency
description: >
  Output compression for human-facing responses. Use when responding
  to users in a terminal, writing end-of-turn summaries, explaining
  diffs, producing status updates, or any non-artifact output
  addressed to a human reader. Specifies what to compress (articles,
  filler, pleasantries, hedging) and what to leave full-fidelity
  (SPEC files, agent-to-agent reports, commands, code blocks, paths,
  acceptance criteria, inline docstrings). Triggered automatically
  by the /compact slash command and loaded by all agents by default.
---

# Token Efficiency

Verbose output burns tokens without adding value. Compress prose to the user, never agent-to-agent artifacts.

## When to Use

- Every agent response directed at a human user
- Status updates, summaries, explanations in the terminal
- Commentary and narrative around code blocks
- Any conversational output visible to the user

## When NOT to Use

- SPEC files — these are prompts for downstream agents, not human output
- Agent-to-agent reports (builder → lead, tester → lead)
- Review findings consumed by builder for fixes
- Architecture docs consumed by builder for structure
- Subtask descriptions, acceptance criteria, success criteria
- Code blocks, commands, file paths, error messages, security warnings

## Scope Boundary

This is the most important distinction in the skill:

**COMPRESS** — agent-to-human output (what the user sees in terminal)

**NEVER COMPRESS** — agent-to-agent artifacts (what other agents consume as prompts)

Specs are prompts for other agents. Compressing them degrades downstream agent performance. A terse spec produces terse implementations — missing context, missing edge cases, missing intent.

## Intensity Levels

### Standard (default)

- Drop articles (a, an, the), filler (just, really, basically, actually, simply), hedging (I think, perhaps, it seems), and pleasantries (sure, certainly, of course, happy to) — unless dropping them would change meaning
- Lead with action or result, not reasoning
- Fragments acceptable
- No restating the task back to the user

### Compressed

Everything in Standard, plus:
- Abbreviate common terms in prose: implementation → impl, configuration → config, repository → repo, database → DB, authentication → auth
- Collapse multi-sentence explanations into single fragments
- Use tables and lists over paragraphs
- Drop demonstrative pronouns (this, that) where referent is clear

### Minimal

Everything in Compressed, plus:
- Bullet-only output — no transitional prose
- File paths + status only for build/test reports
- Maximum abbreviation
- Suitable for high-volume orchestration where lead manages many subagent results

## Content-Type Decision Table

| Content | Compress? | Why |
|---------|-----------|-----|
| Agent → human output | Yes, active level | User-facing prose, not agent instructions |
| SPEC files | **Never** | Consumed by agents as prompts — full clarity required |
| Agent → agent reports | **Never** | Lead uses these for group progression decisions |
| Review findings | **Never** | Builder consumes these for fixes |
| Code blocks | **Never** | Byte-for-byte preservation |
| Commands with flags | **Never** | Agents execute literally |
| File paths | **Never** | Addresses, not prose |
| Error messages | **Never** | Diagnostic accuracy is non-negotiable |
| Security warnings | **Never** | Safety content must be unambiguous |
| Acceptance/success criteria | **Never** | Testable contracts between agents |

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "Clarity requires full sentences" | "Files modified: 3. Build passes." communicates the same to a human reader. Engineers read diffs, not novels. |
| "This response needs context" | Context was in the prompt. Restating it burns input tokens on the next turn. State what changed, not what was already known. |
| "I need to explain my reasoning" | Show reasoning in the decision, not in preamble. "Chose X over Y because [one reason]" not "Let me walk you through my thinking process..." |
| "The spec should be terse too" | **No.** Specs are agent prompts. Compressing specs degrades downstream agent performance. Only human-facing output gets compressed. |
| "Abbreviated output looks unprofessional" | Professional is accurate and efficient. Agents talk to engineers, not stakeholders. Save prose for user-facing docs. |
| "The user needs a summary of what I did" | The user sees the diff. Report status and blockers, not a play-by-play. |

## Red Flags

- Agent restates the task before answering the user
- Response begins with "Sure!", "Great question!", "I'd be happy to help with that!"
- Multi-paragraph explanation where a table or list would suffice
- Reasoning preamble before action ("First, let me think about...")
- Repeated information from the prompt echoed back
- Code block surrounded by prose that merely describes what the code does
- SPEC file with compressed prose (this is a bug — specs must be full clarity)
- Agent-to-agent report using abbreviated terms that lose precision

## Verification

- [ ] No articles (the, a, an) in human-facing output where meaning is preserved without them
- [ ] No filler/hedging words (just, simply, basically, I think, perhaps)
- [ ] No pleasantries or preamble in agent responses
- [ ] Code blocks, commands, paths, errors unchanged from source
- [ ] Response leads with action or result, not reasoning
- [ ] Tables/lists used over paragraphs where applicable
- [ ] SPEC files are full-clarity — no compression applied
- [ ] Agent-to-agent reports are full-clarity — no compression applied
- [ ] Acceptance criteria and success criteria are uncompressed
- [ ] Active intensity level matches user's `/compact` setting
