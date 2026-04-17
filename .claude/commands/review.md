---
description: Review code for correctness, security, and quality
---

Spawn the `reviewer` agent directly in full-review mode for: $ARGUMENTS

This is a standalone command — it does NOT enter the orchestration workflow. Use `/orchestrate` or `/build` if you want mini-review as part of a gated group.

Reviewer walks the diff (`git diff` or `git diff --staged` depending on the scope in `$ARGUMENTS`) and applies the five-axis framework (Correctness, Readability, Architecture, Security, Performance). Every finding has a severity label: Critical, Important, Suggestion, Nit, or FYI. Status is driven by highest severity — Critical or Important → `needs-input`.

Reviewer is read-only. It does not modify code.
