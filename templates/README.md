# Enhancement Proposals (EPs)

This directory holds **Enhancement Proposals** — numbered design
records that capture the *what* and *why* of non-trivial changes to the
project. See [EP-1](./0001-ep-purpose-and-guidelines.md) for the full
process, conventions, and lifecycle.

## When to write one

Write an EP if you're introducing a new public contract, touching a
load-bearing invariant, reversing a prior decision, or answering a
"should we do X or Y?" question that isn't obvious from the code. Skip
it for bug fixes, dep bumps, and contained refactors.

## How to write one

1. Copy `0000-template.md` to `NNNN-short-kebab-title.md` with the next
   unused number (see the index below).
2. Fill in the frontmatter and the expected sections.
3. Open a PR. Iterate. When accepted, update `status: Accepted` and
   merge.

## Index

| #    | Title | Type | Status |
|------|-------|------|--------|
| 0001 | [EP Purpose and Guidelines](./0001-ep-purpose-and-guidelines.md) | Process | Draft |

<!-- Add new entries in numerical order. Keep the table tidy. -->

## Status legend

- **Placeholder** — triage-approved idea with a reserved number and
  a problem statement + open questions. Not yet a worked design.
  Low review bar to merge; the point is rapid capture. See EP-1
  §"Placeholders."
- **Draft** — author is iterating. Design space being actively
  worked out. Content may change.
- **Accepted** — approved for implementation (or, for Informational
  EPs, approved as the canonical record). Content is append-only.
- **Partial** — one or more scoped slices have shipped, but the EP's
  stated goals are not fully implemented.
- **Implemented** — a Standards EP that has shipped. Required
  `implemented-in: vX.Y.Z` in frontmatter points at the release.
- **Superseded** — replaced by a later EP. Frontmatter points forward
  via `superseded-by`.
- **Withdrawn** — author pulled it before acceptance.
- **Rejected** — maintainers declined it. Kept for historical context.

## Types

- **Standards** — proposes a change to code, on-disk layout, CLI, API,
  or user-visible behaviour.
- **Informational** — documents a decision record, convention, or
  historical context. No implementation work implied.
- **Process** — changes how contributors work (e.g., this process doc).

## Frontmatter fields

Required:

```yaml
ep: N
title: Short, descriptive title
author: Name <email@example.com>
status: Placeholder | Draft | Accepted | Partial | Implemented | Superseded | Withdrawn | Rejected
type: Standards | Informational | Process
created: YYYY-MM-DD
history:
  - date: YYYY-MM-DD
    status: Draft
    note: Initial draft.
```

Optional, added as relevant (see EP-1 for full semantics):

```yaml
updated: YYYY-MM-DD
requires: [N, M]          # must-read-first dependencies
extends: [N]              # this EP builds directly on these
supersedes: [N]           # this EP replaces these
superseded-by: [N]        # this EP has been replaced
extended-by: [N, M]       # later EPs build on this one
see-also: [N, M]          # loosely related
implemented-in: vX.Y.Z
discussion-at: <URL>
```

All EP-reference fields are YAML lists even when holding a single
value (`extended-by: [8]`), for tooling consistency.

## Bidirectional links

When a new EP records `extends` or `supersedes`, **the same PR must
update the older EP's reciprocal `extended-by` or `superseded-by`
field**. `requires` and `see-also` do not imply reciprocity. See EP-1
§"Updating EPs" for the full rule.

## Conventions

- **Filename:** `NNNN-short-kebab-title.md`. Titles under ~60 chars.
- **Numbers:** sequential, four-digit, claimed at merge time. Rebase on
  conflict.
- **Decision log:** every Standards EP must have one. Informational
  EPs should have one when they capture rationale (most do).
- **Append-only after Acceptance:** substantive edits go in a new EP
  that supersedes the old.
