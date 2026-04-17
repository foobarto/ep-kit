# EP Review Checklist

Use this checklist when reviewing an Enhancement Proposal PR. Not every item applies to every EP — skip sections marked as type-specific.

## Frontmatter

- [ ] `ep` number matches the filename (NNNN)
- [ ] `title` is descriptive and under ~60 chars
- [ ] `author` has name and email
- [ ] `status` is valid (`Placeholder`, `Draft`, `Accepted`, `Implemented`, `Superseded`, `Withdrawn`, `Rejected`)
- [ ] `type` is valid (`Standards`, `Informational`, `Process`)
- [ ] `created` is a valid YYYY-MM-DD date
- [ ] `history` has at least one entry matching the current status
- [ ] Optional fields (`requires`, `supersedes`, `see-also`) reference real EP numbers
- [ ] All EP-reference fields use YAML list syntax even for single values (`[4]`, not `4`)

## Structure

- [ ] Problem section clearly states what's broken or missing
- [ ] Goals are specific and measurable
- [ ] Non-goals list 2–4 things explicitly out of scope
- [ ] Design section describes the proposed shape (modules, contracts, interfaces)
- [ ] Open questions honestly list deferred decisions (no pretending they're resolved)

## Type-specific sections

### Standards EPs
- [ ] Migration / rollout plan exists
- [ ] Failure modes identified
- [ ] Test strategy described
- [ ] Decision log has at least 3 entries

### Informational EPs
- [ ] Migration, Failure Modes, and Test Strategy are appropriately skipped or included
- [ ] Decision log captures rationale even if retrofitting

### Process EPs
- [ ] Test Strategy is appropriately skipped or included

## Decision log

- [ ] Each entry uses `DX` numbering (D1, D2, …)
- [ ] Each entry has **Decided**, **Alternatives**, and **Why**
- [ ] "Why" explains reasoning, not just restating the decision
- [ ] Alternatives considered are genuine (not strawmen)
- [ ] Entries are append-only (no edits to existing decisions)

## Bidirectional links

- [ ] If this EP `requires` another, the dependency is real and should be read first
- [ ] If this EP `supersedes` another, the old EP's frontmatter is updated in this PR:
  - [ ] `superseded-by` set to this EP's number
  - [ ] `status` changed to `Superseded`
  - [ ] New `history` entry appended
- [ ] If this EP `extends` another, the old EP's `extended-by` is updated in this PR
- [ ] If this EP `see-also` another, the reference is actually relevant

## Scope

- [ ] This EP covers one decision space (not multiple unrelated changes)
- [ ] If scope is broad, it should be split into multiple EPs
- [ ] Non-goals prevent scope creep during implementation

## Quality

- [ ] No unresolved placeholders or TBDs
- [ ] Internal consistency — design matches the stated problem
- [ ] No ambiguity — requirements can't be interpreted two ways
- [ ] Writing is concise — sections scaled to complexity

## If Placeholder status

- [ ] Problem statement is clear
- [ ] Goals / Non-goals exist even at sketch level
- [ ] Open questions section is the load-bearing part
- [ ] At least 1–2 decision log entries for settled things
- [ ] Remaining decision log entries flagged as "to be captured during brainstorm"

## If status change (Draft → Accepted, Accepted → Implemented, etc.)

- [ ] New `history` entry appended with date, status, and note
- [ ] If Implemented, `implemented-in` version is set
- [ ] If Superseded, `superseded-by` is set and matches history entry
