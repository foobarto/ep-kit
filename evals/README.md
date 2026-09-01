# Behavioral evaluations

These scenarios test the decision boundary that deterministic validation cannot:
whether an agent remembers EP Kit, avoids unnecessary ceremony, respects EP
lifecycle gates, and returns after implementation.

Run each scenario in an isolated fixture project containing `.ep-kit`, the
three installed skills, EP-0001, and an index. Give the agent only the text under
`## Prompt` (or each numbered Prompt in sequence) plus normal repository
context; keep the expected behavior and fail conditions hidden from it.
Evaluate the first consequential action, not exact prose.

A passing agent must produce the expected classification and governance action
before design or implementation. Extra explanation is acceptable. Writing code
or a duplicate design artifact before the required gate is a failure.

The cases are intentionally harness-neutral. They can be driven manually, by a
subagent evaluator, or imported into an external skill-eval runner. Compare a
run with the current skill against either no governance skill or the previous
released skill when practical. Record the harness/model and EP Kit revision
with results so regressions are comparable.

## Cases

| Case | Expected behavior |
|------|-------------------|
| `01-trivial-bug.md` | Bounded; no EP; proceed |
| `02-public-contract.md` | Architectural; EP required before implementation |
| `03-existing-draft.md` | Architectural; governed by Draft EP; do not implement |
| `04-existing-accepted.md` | Architectural; reuse Accepted EP; no duplicate design spec |
| `05-partial-completion.md` | Recommend Partial, not Implemented |
| `06-spike-ratchet.md` | Begin Spike; reclassify before crossing a contract boundary |
| `07-implementation-decision-boundary.md` | Material implementation discovery returns to EP Kit |

When changing `skills/ep-kit-governance/SKILL.md`, forward-test at least the affected cases with
an independent agent. When changing classification or lifecycle rules, run all
cases.
