---
name: ep-kit-governance
description: Use before planning, implementing, resuming, or completing project changes in a repository containing .ep-kit. Classifies work as Spike, Bounded, or Architectural; routes EP-worthy decisions into Strata; enforces proposal lifecycle gates; and checks implementation status. Do not use for read-only questions unrelated to a proposed or completed change.
---

# Strata: Govern a Project Change

Keep architectural decisions connected to implementation without turning every
change into an EP. This skill is the project-level activation layer for Strata.
It routes work; `ep-kit` authors proposals and `ep-kit-validate` reviews them.

## Start here

1. Locate `.ep-kit` from the current directory, walking up at most five parent
   directories. If none exists, stop using this skill and continue normally.
2. Resolve the EP directory from `dir=` relative to the config file. Default to
   `docs/eps/` when the key is absent.
3. Identify whether this is a **preflight** (planning, implementing, or
   resuming work) or a **completion check** (reporting or recording delivered
   work).

For preflight, inspect only enough repository context to classify the change.
Do not start design or implementation before classification. For completion,
go directly to §"Completion checkpoint."

## Preflight classification

Classify the requested work once. Reuse an equivalent classification already
made by another workflow; do not make the user brainstorm twice.

- **Spike** — the purpose is to reduce uncertainty. Output is exploratory and
  disposable; it does not establish a durable contract or production design.
- **Bounded** — the change is understood and localized. It does not change a
  public contract, load-bearing invariant, cross-component boundary, security
  or permission model, persistent format, or accepted EP.
- **Architectural** — the change may alter one of those durable boundaries,
  reverses or extends a prior decision, changes contributor governance, or
  spans modules or milestones that need a shared design contract.

Hidden complexity can ratchet Spike → Bounded → Architectural. Never ratchet
down merely to avoid the EP process.

For Spike or Bounded work, state the classification briefly and continue with
the normal project workflow. Do not create an EP. If the work later crosses an
Architectural boundary, stop before that boundary and re-run this preflight.

## Architectural routing

Read `<ep_dir>/0001-ep-purpose-and-guidelines.md` and `<ep_dir>/README.md`.
Search the index and relevant proposal files for an existing decision covering
the change. Use EP-0001's current criteria if they differ from this skill.

An Architectural change is **EP-worthy** when it creates or changes a durable
choice that future contributors must understand, such as:

- a public CLI, API, configuration, schema, protocol, or on-disk contract;
- a load-bearing architectural, compatibility, permission, or trust invariant;
- a reversal, extension, or supersession of an accepted decision;
- a cross-module or staged design needing one stable source of truth; or
- a contributor process decision with genuine alternatives and lasting effect.

Investigation, implementation details, and the route to an already Accepted EP
are not new EPs by themselves.

### If an existing EP governs the work

Read it and follow its current status:

- **Placeholder:** does not authorise implementation. Help mature the idea or
  its open questions first.
- **Draft:** does not authorise implementation. Help review or accept the
  proposal first.
- **Accepted:** the design is approved and implementation may begin under the
  project's ordinary execution authority. Treat the EP as authoritative.
- **Partial:** accepted scope has partially shipped. Remaining accepted scope
  may continue; treat the EP and its recorded open obligations as authoritative.
- **Implemented:** ordinary maintenance within the contract is Bounded. A new
  decision that changes the contract needs an extending or superseding EP.
- **Superseded:** do not implement it as the current design; follow
  `superseded-by` before classifying the work.
- **Withdrawn or Rejected:** do not implement it as an approved design. A
  materially new proposal requires a new EP that cites the historical one.

For Accepted or Partial work, confirm the requested work stays within its
goals, non-goals, decisions, and open questions. Give its path to any downstream
implementation-planning workflow as the spec; do not create a duplicate design
document.

The status is the proposal's authority signal. A request to implement a
Placeholder or Draft is not itself a waiver. Only a separate explicit
instruction that acknowledges the unaccepted status and authorises work before
acceptance can override the gate; an autonomy level or task assignment cannot.
Such an override does not change the proposal's status.

During implementation, keep local and reversible choices in the implementation
record. Stop at the decision boundary and route through a new extending or
superseding EP when a discovered choice changes a public contract, persisted
representation, trust or security boundary, load-bearing invariant, or an
existing EP decision; materially constrains future implementations; or merits
its own honest alternatives and rationale. A work log or session journal may
record where the issue surfaced, but it does not replace the durable EP.

### If no existing EP governs the work

- **EP-worthy:** invoke the `ep-kit` authoring skill. Preserve answers already
  established by prior brainstorming and ask only unresolved questions. The EP
  replaces any workflow's design-spec artifact; after acceptance, downstream
  planning cites the EP path as its specification.
- **Not EP-worthy:** state why the durable-governance threshold is not met and
  continue with the normal design or implementation workflow. Do not create an
  EP for ceremony's sake.

Do not implement a newly created Placeholder or Draft unless the same explicit
unaccepted-status override is given. Acceptance is a human or
project-governance decision, not an inference from a completed draft.

## Completion checkpoint

Run this checkpoint when completed work was governed by an Accepted or Partial
Standards or Process EP. Read the EP again and compare evidence from the
implementation and tests with every stated goal, non-goal, migration or rollout
obligation, and applicable test strategy item. Informational EPs normally have
no implementation lifecycle to update.

Recommend exactly one outcome:

- **Remain Accepted:** no meaningful production slice has shipped yet.
- **Partial:** one or more scoped slices shipped, but any stated goal or rollout
  obligation remains open.
- **Implemented:** every stated goal and rollout obligation is satisfied and
  the relevant checks pass. For Standards EPs, the first shipped release must
  also be known for `implemented-in`.

Do not infer full implementation from a merged PR, passing unit tests, or a
claim that the code is "done." State the evidence and the remaining gaps.

Changing lifecycle metadata is a durable governance action. Make the change
only when the user explicitly requests it or the project's instructions grant
that authority. When authorized:

1. update the top-level status and `updated` date;
2. append, never rewrite, a matching `history` entry;
3. add `implemented-in` for an Implemented Standards EP;
4. update the README index; and
5. run the configured validator on the entire EP directory.

## Interoperability

Strata owns the durable architectural record, not the implementation method.
When another methodology is present:

- reuse its Spike / Bounded / Architectural result if equivalent;
- reuse its completed brainstorming as input to EP authoring;
- for EP-worthy Architectural work, create one EP instead of a second design
  spec;
- after the EP is Accepted, let the implementation methodology resume from
  planning, with `Spec: <path-to-ep>`; and
- return here after implementation for the lifecycle checkpoint.

Other tools may cite the governing proposal as `EP-NNNN` and a specific
Decision Log entry as `EP-NNNN D<N>`. These canonical textual forms are
independent of the configured frontmatter number key.

Do not introduce requirements for TDD, worktrees, subagents, debugging, code
review, or implementation-plan format. Those remain downstream policy choices.

## Required report

Keep the routing result concise:

```text
Strata: <Spike | Bounded | Architectural>
Governance: <no EP | EP required | governed by EP-NNNN>
Gate: <may proceed | needs Draft/Placeholder work | needs acceptance | needs new EP>
Next: <one concrete action>
```
