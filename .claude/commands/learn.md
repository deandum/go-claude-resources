---
description: Record a project-specific learning for future sessions
---

Record the following learning about this project using the learn script.

Run: `$ARGUMENTS`

If no argument provided, ask what the user learned.

Execute the learning script:
```bash
"${CLAUDE_PLUGIN_ROOT}/hooks/learn.sh" "<the learning text>" "<category if mentioned, otherwise convention>"
```

Valid categories: convention, gotcha, pattern, tool.
