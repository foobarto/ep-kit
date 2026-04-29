---
name: ep-kit-validate
version: 1.0.0
description: Use when the user wants to review or validate an existing Enhancement Proposal for semantic quality. Triggers on phrases like "review this EP", "validate EP-3", "is this EP good?", "check EP quality", "EP review". Performs a thorough semantic audit covering problem clarity, decision log honesty, scope correctness, alternative quality, and internal consistency.
---

# EP Kit: Validate an EP

Perform a **semantic review** of an Enhancement Proposal. This is the
quality gate that runs after the mechanical validator (`validate.sh`)
passes — it catches hollow reasoning, scope creep, and dishonest
decision logs that no script can detect.

## When to use this skill

- User asks to "review this EP", "validate EP-N", "is this EP ready?"
- User wants a second opinion before submitting an EP PR.
- User is reviewing someone else's EP and wants structured feedback.
- After `validate.sh` passes — the script catches syntax, this catches
  substance.

**Do NOT use this skill for:**

- Checking frontmatter syntax or file naming (use `validate.sh`).
- Writing or editing an EP (use the `ep-kit` skill instead).
- General code review (use a code review skill).

## Configuration resolution

Resolve the EP directory using the same logic as the `ep-kit` skill:

1. **`EP_DIR` environment variable** — if set, use it.
2. **`.ep-kit` config file** — search from CWD up to 5 parent levels.
   If found with `dir=<path>`, use that.
3. **Default:** `docs/eps/`.

Use the resolved `<ep_dir>` to locate `<ep_dir>/0001-ep-purpose-and-guidelines.md`
and other EPs.

## Prerequisites

1. **Run `validate.sh` first.** If the mechanical checks fail, fix those
   before doing semantic review. No point reviewing an EP with broken
   frontmatter.
2. **Read EP-1** for the project's conventions. `<ep_dir>/0001-ep-purpose-and-guidelines.md`
   is the authority.
3. **Read the EP being reviewed** in full.
4. **Read any referenced EPs** (requires, supersedes, see-also) for
   context.

## Review dimensions

Evaluate the EP across these dimensions. For each, give a verdict
(Pass / Concern / Fail) with a one-sentence rationale.

### 1. Problem clarity

- Is the problem concrete and specific?
- Could a reader understand *why* this EP exists without external context?
- Is it a real problem, or a solution looking for one?

**Red flags:**
- Problem is vague ("we should improve X")
- Problem is actually a feature request without pain
- Problem statement is more than 3 paragraphs (scope issue)

### 2. Goals alignment

- Do the goals directly address the stated problem?
- Are goals measurable ("reduce latency by X%") not aspirational
  ("make it faster")?
- Is there a goal the problem doesn't justify?

### 3. Non-goals quality

- Are non-goals meaningful constraints, not just "not doing everything"?
- Do they actually prevent scope creep?
- Is anything important accidentally excluded?

**Red flags:**
- Only 1 non-goal (scope is too open)
- Non-goals are obviously out of scope anyway ("we won't rewrite the
  kernel")
- Non-goals contradict the goals

### 4. Design coherence

- Does the design actually solve the stated problem?
- Is the design at the right level of detail for an EP (not an
  implementation plan)?
- Are interfaces and contracts clearly specified?
- Does the design introduce unnecessary complexity?

**Red flags:**
- Design is a list of implementation steps, not an architectural shape
- Design introduces new concepts not needed for the problem
- Key interfaces are underspecified ("we'll figure out the API later")

### 5. Decision log honesty

This is the most important dimension.

For each decision log entry:
- Does **Why** explain reasoning, or just restate **Decided**?
  (If it restates, the reasoning isn't captured — flag it.)
- Are **Alternatives** genuine options, or strawmen?
  (If the "alternative" is obviously bad, it wasn't really considered.)
- Is there a material choice that *doesn't* have an entry?
  (Every non-obvious decision needs one.)

**Red flags:**
- "Why: because it's better" — not a reason
- "Alternatives: doing nothing" — not a real alternative
- "Decided: use a database" with no explanation of which or why
- Decision log has 1 entry for a complex EP

### 6. Scope discipline

- Is this EP about **one** decision space?
- If you removed any section, would the EP still make sense?
  (If yes, that section belongs in a separate EP.)
- Are there implementation details that belong in a plan, not an EP?

**Red flags:**
- EP covers both "what to build" and "how to build it"
- EP has subsections for unrelated features
- "Phase 2" and "Phase 3" sections that are really separate proposals

### 7. Migration realism

(Standards EPs only)

- Is the migration path actually feasible, or hand-wavy?
- Does it account for existing users/data/configs?
- Is there a rollback plan if things go wrong?

### 8. Failure mode coverage

(Standards EPs only)

- Are the failure modes realistic, not hypothetical?
- Is there a failure mode the author missed?
- Are the surfacing mechanisms actionable?

### 9. Open questions honesty

- Are the open questions genuinely undecided, or decisions the author
  doesn't want to defend?
- Is "we'll figure this out" being used to dodge a hard choice?
- Are there decisions that *should* be made now but are deferred?

### 10. Bidirectional link semantics

The validator checks that referenced files exist. This dimension checks
whether the links *make sense*:

- Does `see-also` actually point to relevant EPs, or is it padding?
- If this EP `requires` another, is the dependency real or just a
  courtesy reference (should be `see-also` instead)?
- If this EP `extends` another, does the old EP's content actually
  relate to what's being added?
- Are there obvious related EPs that *should* be linked but aren't?

**Red flags:**
- `see-also` lists every EP in the project (link spam)
- `requires` points to an EP that's tangentially related at best
- A clearly related EP (same subsystem, same decision space) is
  not referenced at all

## Output format

Produce a structured review:

```markdown
# EP Review: EP-NNNN — Title

## Verdict: Pass / Revise / Reject

One-sentence summary.

## Dimension scores

| Dimension | Verdict | Note |
|-----------|---------|------|
| Problem clarity | Pass | ... |
| Goals alignment | Concern | ... |
| Non-goals quality | Pass | ... |
| Design coherence | ... | ... |
| Decision log honesty | ... | ... |
| Scope discipline | ... | ... |
| Migration realism | ... | ... |
| Failure mode coverage | ... | ... |
| Open questions honesty | ... | ... |
| Bidirectional link semantics | ... | ... |

## Specific feedback

### Must fix (blocking)

- Item 1
- Item 2

### Should fix (recommended)

- Item 1

### Nit (optional)

- Item 1

## Overall assessment

2-3 paragraphs on the EP's strengths, weaknesses, and readiness.
```

## Batch review mode

If the user asks to review multiple EPs (e.g., "review all Draft EPs"),
iterate through each EP in `<ep_dir>/` that matches the criteria and
produce a consolidated report:

```markdown
# Batch EP Review

## Summary

| EP | Title | Verdict | Key issue |
|----|-------|---------|-----------|
| EP-3 | ... | Pass | — |
| EP-5 | ... | Revise | Missing failure modes |
| EP-7 | ... | Reject | Scope covers 3 decision spaces |

## Per-EP details

### EP-5 — Title

[Full review output]

### EP-7 — Title

[Full review output]
```

## Rules

- **Be specific.** "The design is unclear" is not useful. "The design
  doesn't specify how module X communicates with module Y" is.
- **Don't rewrite.** Suggest improvements; don't produce the improved
  text unless asked.
- **Flag dishonest decision logs.** This is the most common EP failure
  mode. If "Why" doesn't explain reasoning, call it out.
- **Respect the EP/plan boundary.** If the EP reads like an
  implementation plan, note that — but don't demand plan-level detail
  in an EP.
- **Be constructive.** The goal is a better EP, not a takedown.
