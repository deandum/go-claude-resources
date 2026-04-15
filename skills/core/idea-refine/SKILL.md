---
name: idea-refine
description: >
  Pre-spec idea refinement through structured divergent and convergent
  thinking. Use when a task is too vague for /define — needs exploration
  before spec generation. Triggers: "ideate", "brainstorm", "refine idea".
---

<!-- meta-skill: invoked via /ideate command, not loaded into agent skills lists -->

# Idea Refine

Refine raw ideas into sharp, actionable concepts before writing a spec.

## When to Use

- "I have an idea but not a task"
- Exploring feasibility of an approach
- Comparing multiple directions before committing
- Pre-spec brainstorming for complex features
- Stakeholder said something vague — need to sharpen it

## When NOT to Use

- Requirements already clear (go straight to `/define`)
- Implementation work (use builder)
- Code review or testing (use reviewer/tester)
- Single, well-defined bug fix

## Core Process

### Phase 1: Understand & Expand (Divergent)

**Goal:** Open up the solution space.

1. **Restate as "How Might We"** — transform the idea into a problem statement. "Make it faster" becomes "How might we reduce p99 latency below 50ms for the payment flow?"
2. **Ask sharpening questions** (3-5 max):
   - Who is this for, specifically?
   - What does success look like?
   - What are the real constraints?
   - What's been tried before?
   - Why now?
3. **Generate 5-8 variations** using these lenses:
   - **Inversion**: what if we did the opposite?
   - **Constraint removal**: what if time/tech weren't factors?
   - **Simplification**: what's the 10x simpler version?
   - **Combination**: merge with an adjacent idea?
   - **Audience shift**: what if this were for a different user?

If inside a codebase: scan for existing patterns, prior art, architectural constraints. Ground variations in reality.

### Phase 2: Evaluate & Converge

1. **Cluster** resonating ideas into 2-3 distinct directions
2. **Stress-test** each against:
   - **User value**: painkiller or vitamin?
   - **Feasibility**: what's the hardest part?
   - **Differentiation**: what makes this genuinely different?
3. **Surface hidden assumptions** — for each direction:
   - What must be true (dealbreaker if wrong)?
   - What could kill this idea?
   - What are we choosing to ignore (and why that's ok for now)?

Be honest, not supportive. Weak ideas get called out with specificity and kindness.

### Phase 3: Sharpen & Ship

Produce a concrete artifact — a task statement ready for `/define`:

```
## [Idea Name]

**Problem:** [one-sentence "How Might We" framing]
**Direction:** [chosen approach and why — 2-3 sentences max]

**Assumptions to Validate:**
- [ ] [Assumption 1 — how to test it]
- [ ] [Assumption 2 — how to test it]

**MVP Scope:** [minimum version that tests the core assumption]

**Not Doing (and Why):**
- [Thing 1] — [reason]
- [Thing 2] — [reason]

**Open Questions:**
- [Anything unresolved before building]
```

When complete, suggest running `/define` to generate a structured spec.

## The "Not Doing" List

The most valuable part of ideation. Focus is about saying no to good ideas.

- Forces explicit trade-offs instead of implicit scope creep
- Prevents "while we're at it" additions
- Creates a reference for future scope discussions
- Every item needs a reason — "not now" is not a reason

## Common Rationalizations

| Shortcut | Reality |
|----------|---------|
| "The idea is obvious, skip to building" | Obvious ideas have hidden assumptions. 5 minutes refining saves 5 hours building the wrong thing. |
| "We need more research first" | Research without a frame is procrastination. Start with what you know, surface what you don't. |
| "Let's just try it and see" | Trying without criteria for success means you can't tell if it worked. Define success first. |
| "We need to consider all options" | 5-8 considered variations beat 20 shallow ones. Depth over breadth. |

## Red Flags

- Jumping straight to solution without framing the problem
- No assumptions surfaced before committing to a direction
- More than 8 variations generated (breadth without depth)
- Skipping "who is this for" — every idea starts with a person and their problem
- No "Not Doing" list — means scope isn't bounded
- Yes-machining weak ideas instead of pushing back
- Ignoring existing codebase constraints when ideating inside a project

## Verification

- [ ] Clear "How Might We" problem statement exists
- [ ] Target user and success criteria defined
- [ ] Multiple directions explored (not just the first idea)
- [ ] Hidden assumptions explicitly listed with validation strategies
- [ ] "Not Doing" list makes trade-offs explicit
- [ ] Output is a concrete artifact, not just conversation
- [ ] Ready for `/define` to generate a structured spec
