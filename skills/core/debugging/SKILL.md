---
name: debugging
description: >
  Debugging discipline: reproduce, isolate, root-cause, fix. Use when
  chasing bugs, tracking down failing tests, or investigating incidents.
  Pair with core/testing for regression coverage.
---

# Debugging

Bugs are surprises. The job is not to make the surprise go away — it is to understand why you were surprised, and leave the system in a state where the same surprise cannot happen again silently.

## When to Use

- A test fails and you do not know why
- A bug is reported from production
- An incident requires a root cause
- Unexpected behavior shows up while implementing a feature
- Performance regresses without a clear cause

## When NOT to Use

- You already know the fix and it is trivial — just fix it
- You have not tried to understand the code yet — read first
- The "bug" is actually a feature request disguised as a bug

## Core Process

### 1. Reproduce reliably

If you can't reproduce it, you can't fix it. Nothing else matters until this step is done.

- Write the exact steps. Not "sometimes it happens" — the specific conditions.
- Convert the repro into a failing test if you can. Even a scrappy one.
- If it's intermittent, find the variable that changes: concurrency, time, input size, state. Then control it.

An unreproducible bug is not fixed by hope. If you cannot reproduce, say so explicitly and escalate.

### 2. Shrink the input

Cut everything that isn't required to trigger the bug. Smaller inputs make smaller hypotheses. A 500-line repro that fails is less useful than a 10-line repro that fails.

### 3. Form a hypothesis and test it

A hypothesis is a falsifiable statement about cause. "Something is broken" is not a hypothesis. "The retry loop drops the context on the second attempt, so the timeout never fires" is.

For each hypothesis:

- Predict what you'd see if it were true
- Run an experiment that would either confirm or refute it
- Record the result before moving on

### 4. Bisect when the history is suspect

If the bug appeared between version A (good) and version B (broken), `git bisect` is the fastest path. It is mechanical — follow the steps, trust the process. Tag the first bad commit and read it.

### 5. Find the root cause, not the first plausible cause

The first thing that looks like a cause is often a symptom. Keep asking "but why does that happen?" until the answer is either external (OS, network, clock, user input) or fundamental (invariant violated, contract broken).

A fix applied to the symptom is a fix that comes back.

### 6. Fix, then prove it with a regression test

Every bug fix ships with a test that:

1. Fails on the pre-fix code
2. Passes on the post-fix code

This is the only evidence the fix works. "I manually tested and it looked fine" is not evidence.

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "I can't reproduce it but I think I know the fix." | You don't know the fix. You're guessing. Reproduce first. |
| "It's flaky — let me just add a retry." | Retries mask races. Find the race. |
| "I'll fix the symptom; the root cause is out of scope." | The symptom comes back dressed differently. Fix the cause. |
| "It works on my machine." | Then it's an environment bug. That's still a bug — find the difference. |
| "The test is wrong, not the code." | Maybe. Prove it. A failing test is data, not an attack. |

## Red Flags

- "Fixed" with a retry loop, a broad try/catch, or a sleep
- Bug fix PR with no regression test
- Fix commit message says "cleanup" or "misc"
- Debugging session that skips reproduction
- Root cause of "something weird with caching"
- Hypothesis that is never tested, just acted on
- Symptom fix when the actual cause is still unknown

## Verification

- [ ] Reproduced the bug reliably, with exact steps written down
- [ ] Minimal repro (removed everything that wasn't load-bearing)
- [ ] Root cause identified and articulated — not just a fix that worked
- [ ] Regression test added that fails on pre-fix code and passes on post-fix
- [ ] Full test suite passes after the fix
- [ ] Commit message explains what broke and why — not just "fix bug"
