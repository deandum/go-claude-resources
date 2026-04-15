---
description: Set output compression level for token efficiency
---

Set token-efficiency level for this session. Applies to human-facing output only — SPEC files and agent-to-agent artifacts are never compressed.

## Usage

```
/compact              → Toggle between standard and compressed
/compact standard     → Default: drop articles, filler, pleasantries
/compact compressed   → Standard + abbreviations, fragments, tables over paragraphs
/compact minimal      → Bullet-only, paths + status, maximum brevity
```

## What Changes

- **Human-facing output**: Compressed at the selected level
- **SPEC files**: Never compressed (agent-to-agent prompts need full clarity)
- **Code blocks, commands, paths**: Never compressed
- **Agent-to-agent reports**: Never compressed

Refer to `core/token-efficiency` skill for the full content-type decision table.
