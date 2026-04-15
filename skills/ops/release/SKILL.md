---
name: ops/release
description: >
  Release publication discipline: semver decision, tag creation,
  changelog generation, GitHub Releases. Part of the opt-in ops-skills
  plugin. Use ONLY when ops_enabled=true. Pair with core/git-workflow
  §6 for versioning strategy selection.
---

# Release

A release is a promise: "this version is stable, supported, and downstream-safe." Releases ship with tags, changelogs, and expectations. This skill covers the mechanics of cutting a release safely. For versioning-scheme selection (semver vs. calvert), see `core/git-workflow` §6.

## When to Use

- Publishing a new version of a library or service
- Tagging a release in git
- Generating a changelog from commit history
- Publishing GitHub Releases with notes and artifacts
- Deciding between major / minor / patch under semver

## When NOT to Use

- Session context has `ops_enabled=false` — **do not publish releases**, report the intended release as a follow-up
- Internal-only deployments that do not need versioned releases — deploy directly
- Pre-release experiments — tag as `v1.0.0-rc.1` or similar, never as a stable version

## Core Process

### 1. Decide the version bump

Under semver (`MAJOR.MINOR.PATCH`):

- **PATCH** (`0.0.X`) — bug fixes, no API changes, no behavior changes for existing callers
- **MINOR** (`0.X.0`) — new features, backwards-compatible additions
- **MAJOR** (`X.0.0`) — breaking changes, removed or changed behavior

Rule: if any existing caller needs to change code to keep working, it is a MAJOR bump. "It's a small change" is not a reason to skip a MAJOR bump — it is a reason to be surprised at how small a breaking change can be.

Under calvert (`YYYY.MM.DD` or `YY.MINOR`): the date is the version. No judgment call, no debate.

### 2. Write the release notes first

Before creating the tag, draft the release notes:

- **Title** — the version and a one-line summary
- **Highlights** — the 2-3 changes a user would notice
- **Breaking changes** — every one, with migration notes (MAJOR only)
- **Bug fixes** — one bullet each, linked to issue or PR
- **Dependencies** — version changes in upstream deps that matter

Release notes say *why* each item matters to a user, not *what* the diff says. "Fixed race in worker pool" beats "Modified pool.go to use sync.Once".

### 3. Tag from the exact commit

Tags are annotations on commits, not branches:

```
git tag -a v1.2.3 -m "Release v1.2.3"
```

Never create a tag from a branch head without confirming the commit. The branch may have moved since your last pull. Always: fetch, confirm the commit SHA, then tag.

### 4. Push the tag deliberately

See `ops/git-remote` §4 — push the tag by explicit name:

```
git push origin v1.2.3
```

Not `--tags`. The explicit name is the confirmation step.

### 5. Publish the GitHub Release

`gh release create v1.2.3 --notes-file release-notes.md` (or the platform's equivalent):

- Attach built artifacts if applicable (binaries, checksums, signatures)
- Mark as pre-release if appropriate
- Link to the commit, CI run, and any security advisory

### 6. Never un-release

A published release is immutable. If it was wrong:

- Publish a patch release with the fix
- Mark the old release as deprecated (some platforms support this)
- Announce the issue in the new release notes

Deleting a release deletes checksums and signatures that downstream consumers may depend on. Do not.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "It's a small change, I'll bump PATCH instead of MAJOR." | If anything breaks for a caller, it's MAJOR. Size is irrelevant. |
| "I'll write the release notes later." | You won't. Or you will, and they'll be wrong because the details faded. |
| "Tagging from the branch head is fine — I just pushed." | Someone else may have pushed after. Confirm the SHA. |
| "I'll delete the release and re-cut it — cleaner." | You'll break downstream checksums. Cut a new patch instead. |
| "I'll push with `--tags` to save a step." | You'll push every local tag, including scratch tags. Push by name. |

## Red Flags

- Release notes generated from commit messages verbatim — no editing for user-facing relevance
- Release cut without running the full test suite on the exact tagged commit
- Tag created without `-a` (unannotated tags lose author/date/message)
- Releases deleted or re-created after publication
- Version bumps that understate the impact (MINOR instead of MAJOR)
- "Latest" tags that move — the point of a tag is that it does not move
- Releases without build artifacts or checksums for downstream verification

## Verification

- [ ] `ops_enabled=true` confirmed in session context before any release command
- [ ] Version bump justified against the change set (semver rules applied)
- [ ] Release notes drafted and reviewed before tagging
- [ ] Tag created with `-a` from the exact intended commit SHA
- [ ] Tag pushed by explicit name, not `--tags`
- [ ] GitHub Release (or equivalent) published with notes and artifacts
- [ ] When `ops_enabled=false`: release reported as a follow-up with proposed version and draft notes
