---
name: ep-kit
description: Use when an EP Kit governance preflight routes an architectural decision to proposal authoring, or when the user explicitly asks to create, extend, or supersede an Enhancement Proposal. Do not use to classify ordinary project work; use ep-kit-governance first.
---

# Enhancement Proposal Kit: Write a New EP

Guide the user through creating a new **Enhancement Proposal**
in the project's EP directory. An EP is a numbered design record — see
`<ep_dir>/0001-ep-purpose-and-guidelines.md` for the full process.

The process is deliberately Q&A-driven: skip steps at your peril. Most
EP anti-patterns (missing rationale, unclear scope, no alternatives
documented) come from skipping the brainstorming and jumping straight
to writing.

## Configuration resolution

Resolve these values at startup. They control where EPs live, what
frontmatter field name to use, and where the validator script is.

### EP directory (`<ep_dir>`)

Resolve in this order (first match wins):

1. **`EP_DIR` environment variable** — if set, use it.
2. **`.ep-kit` config file** — search for `.ep-kit` starting from
   CWD, then walk up parent directories (up to 5 levels deep).
   If found and it contains `dir=<path>`, use that path (relative
   to the config file's directory).
3. **Default:** `docs/eps/`.

### EP prefix (`<prefix>`)

The frontmatter field name for the EP number (e.g. `ep: 3` or
`rfc: 3`). Resolve in this order:

1. **`.ep-kit` config file** — if found (see above) and it contains
   `prefix=<name>`, use that value.
2. **Default:** `ep`.

### Validator path (`<validator>`)

Path to `validate.sh`. Resolve in this order:

1. **`.ep-kit` config file** — if found and it contains
   `validator=<path>`, use that path.
2. **Auto-discovery** — search for `validate.sh` in these locations
   (first match wins):
   - `validate.sh` adjacent to this `SKILL.md` (the plugin/skill-bundled helper;
     resolve it relative to the loaded skill, not the working directory)
   - `scripts/validate-eps.sh` (default vendored installation)
   - `<ep_dir>/../../validate.sh` (ep-kit installed as sibling)
   - `<ep_dir>/../validate.sh` (ep-kit installed as parent)
   - `.agents/skills/ep-kit/validate.sh` (skill directory)
   - `.claude/skills/ep-kit/validate.sh` (skill directory)
3. **Auto-configure** — if a project-relative validator is found via
   auto-discovery, write
   `validator=<path>` to `.ep-kit` (create the file if it doesn't
   exist) and notify the user: "Auto-configured validator path in
   .ep-kit — you can change it in the config file." Do not persist a plugin
   cache path for the skill-bundled helper; use it only for the current run.
4. **Not found** — if no validator is found, skip mechanical
   validation. Tell the user: "Validator not found. Run `install.sh`
   from the ep-kit directory or set `validator=` in `.ep-kit`."

Substitute `<ep_dir>`, `<prefix>`, and `<validator>` everywhere below.

## .ep-kit config format

A plain text file with `key=value` lines, one per line. Blank lines
and lines starting with `#` are ignored. Supported keys:

```
dir=docs/eps               # EP directory (relative to config file)
prefix=ep                  # frontmatter field name (default: ep)
validator=scripts/validate-eps.sh  # path relative to the config file
skip_sections=1            # skip required section checks (for retrofits)
kit_version=1.2.0          # ep-kit version this config was generated for
```

## Setup check

Before starting Phase 1, verify the EP directory exists and has the
template:

- If `<ep_dir>/0000-template.md` exists → proceed.
- If it doesn't exist → tell the user: "EP directory not scaffolded.
  Run `install.sh` from the ep-kit directory first, or create
  `<ep_dir>/` with `0000-template.md` and
  `0001-ep-purpose-and-guidelines.md`." Do not proceed until the
  directory is ready.

## When to use this skill

- The `ep-kit-governance` skill classified a change as Architectural and
  EP-worthy with no existing proposal governing it.
- User says "let's write an EP", "new EP for X", "document this as an
  EP", "propose X".
- User is describing a design change that touches a public contract,
  on-disk layout, CLI surface, API, permission model, or any of the
  project's architectural invariants.
- User is reversing or extending a prior EP.

**Do NOT use this skill for:**

- Bug fixes, doc tweaks, dep bumps, perf work with no API change.
- Open-ended brainstorming that hasn't narrowed down to a concrete
  proposal yet — finish the brainstorm first, then EP the decision.
- Questions about EPs (read EP-0001 directly).

If another design or brainstorming workflow already established answers to
the questions below, preserve those answers and ask only what remains
unresolved. For EP-worthy work, this EP is the durable design artifact; do not
also write a parallel design spec for the same decision.

## Prerequisites — always check first

1. **Read EP-0001.** `<ep_dir>/0001-ep-purpose-and-guidelines.md` is
   the authority on format, numbering, lifecycle, and conventions. If
   it has been updated since this skill was written, EP-0001 wins.
2. **Read the index.** `<ep_dir>/README.md` shows existing EPs; pick
   the next unused number and survey what's already decided.
3. **Detect architectural baseline (optional).** Scan the index for
   an Informational EP with `extended-by` containing 3+ entries —
   that's likely the project's architectural baseline (like EP-0001).
   If found, read it for context. Most Standards EPs will
   reference it via `requires: [N]`.

## Process

### Phase 1 — Scope and framing (one question at a time)

Ask these one at a time. Don't batch. Wait for each answer before the
next.

**Exception:** if the user volunteers answers to multiple questions in
their initial message (e.g., "new EP for X, Standards type, triggered
by Y, non-goals are Z, let's go Draft"), accept the answers they've
provided and skip to the first unanswered question. Don't re-ask
questions the user has already answered.

**Q1: What are you proposing?** One sentence. If the answer takes a
paragraph, the scope is probably too wide — push back and ask the user
to narrow it to one decision space.

**Q2: What triggered this?** Concrete problem, missing capability,
contested part of the codebase, or a conversation that needs a stable
record. If the answer is "it seemed like a good idea," that's a red
flag — EPs are for load-bearing decisions.

**Q3: Is this Standards, Informational, or Process?**

- **Standards** — changes code, on-disk layout, CLI, API, or user
  behaviour.
- **Informational** — captures a decision record or convention
  without proposing implementation.
- **Process** — changes how contributors work.

**Q4: Does this supersede or extend an existing EP?**

- List any related EPs by number. If one is being superseded, its
  frontmatter must be updated in the same PR (see EP-0001 "Updating
  EPs" section).
- If it extends one, add `extends: [N]` and be ready to update that
  EP's reciprocal `extended-by` field. Use `requires` only when the
  earlier EP is a must-read dependency; it does not imply extension.

**Q5: What's explicitly NOT in scope?** This matters. EPs sprawl
without firm non-goals. Ask the user to list 2–4 things this proposal
deliberately doesn't do.

**Q6: Is this ready for a full Draft, or should it land as a
Placeholder first?** A Placeholder is a lower-bar parking spot —
problem statement + goals + open questions + one or two settled
decisions. Appropriate when:

- The idea is worth capturing now but the design space is only
  partially worked out.
- The author (maintainer or triage-approved contributor) wants to
  reserve an EP number without committing to the full shape.
- Most design decisions are still genuinely open.

A full Draft is appropriate when the design space is substantially
explored and the author is ready to defend concrete choices.

Default: if the user has clear answers to Q1–Q5 and 3+ decisions
they can articulate, go Draft. If they're iterating on the shape
and have more open questions than decisions, suggest Placeholder.

After Q1–Q6: summarize what you've heard and ask "does that sound
right?" before moving on. If the user revises, update your summary;
don't silently re-interpret.

### Phase 2 — Design (adaptive)

Now dig into the *design*. Depth depends on complexity:

- **Small EP** (one module, one decision): maybe 2–3 questions.
- **Large EP** (multi-module, affects contracts): 5–10 questions.
- **Informational retrofit**: mostly summarizing existing state, fewer
  questions — but still capture alternatives considered in the
  original design if the user remembers them.

Cover, in order:

1. **Design shape** — modules, data structures, contracts. For
   Informational EPs, this is the "what is" being documented.
2. **Interfaces** — what callers see, what dependents expect.
3. **Migration or rollout** — how does this land without breaking
   anything? Skip for Informational EPs.
4. **Failure modes** — what can go wrong? How does it surface? Skip
   for Informational and Process.
5. **Testing** — how is correctness validated? Skip for Informational
   and Process.

Each question should be **one question at a time**. Offer 2–3 options
with tradeoffs where possible, with your recommendation. The user
refining a recommendation is faster than a blank-page "what do you
think?"

### Phase 3 — Decision log (required, load-bearing)

This is the part most authors want to skip. Don't let them.

For every non-obvious choice the EP makes, capture:

- **Decided:** what the EP commits to.
- **Alternatives:** what else was considered.
- **Why:** one or two sentences of reasoning.

Walk the user through every material choice from phases 1–2 and
extract the decision log format. Number them **D1, D2, …** (not
hierarchical — easier to cite). Cite a proposal as `EP-NNNN` and one of its
decisions as `EP-NNNN D<N>`, regardless of the configured frontmatter number
key.

Minimum bars by status:

- **Placeholder:** at least 1–2 decision log entries for things
  already settled. Remaining entries explicitly flagged "to be
  captured during the brainstorm that takes this EP to Draft."
  The §"Open questions" section carries the weight for a
  Placeholder.
- **Draft:** at least 3 decision log entries for a Standards EP.
  If you can't find three, either the EP is trivial (shouldn't be
  an EP) or you haven't dug deep enough into alternatives.

For Informational retrofits, capture the decisions from the original
design even if the author isn't present — "why did the original design
pick X?" is still the question. If the answer is "I don't know,"
record that honestly (`Why: rationale not preserved; current code
reflects this choice`).

### Phase 4 — Write the file

Once the Q&A is complete:

1. **Pick the next EP number.** Check `<ep_dir>/README.md` index
   for the highest existing number. Add 1. Example: if `EP-0008` is the
   latest, write `EP-0009`.
2. **Copy the template.** `<ep_dir>/0000-template.md` is the
   skeleton. Rename to `<ep_dir>/NNNN-short-kebab-title.md`.
3. **Fill in the frontmatter** — `<prefix>`, `title`, `author`,
   the status selected in Q6 (`Placeholder` or `Draft`), `type`, `created`
   (today's date), and relevant
   optional fields (`requires`, `extends`, `supersedes`, `see-also`). Fields
   like `discussion-at` and `implemented-in` are filled later when
   the EP moves to Accepted or Implemented status.
4. **Initialize the `history` field** with one entry matching the selected
   `Placeholder` or `Draft` state. Date is today. Note should be concise —
   "Initial placeholder," "Initial draft," or "Retrofitted from pre-EP notes."
   Every subsequent status change (Draft→Accepted, Accepted→Partial,
   Partial→Implemented, etc.) appends a new entry in the PR that changes the
   status. Never edit or delete history entries.
5. **Write the content** drawing on the Q&A answers. Scale each
   section to its complexity — short is fine. Kill placeholders.
6. **Write the decision log** from Phase 3. This is the part that
   makes it an EP and not just a spec.
7. **Update the README index.** Add a row in the table in
   `<ep_dir>/README.md`.
8. **If extending/superseding, update the linked EP's frontmatter.**
   Both changes ship together, same session:

   **When superseding `EP-NNNN`:**
   - On the *old* EP: set `status: Superseded`
   - On the *old* EP: add `superseded-by: [M]` (use YAML list syntax)
   - On the *old* EP: append a `history` entry with today's date,
     `status: Superseded`, and a note like "Superseded by EP-MMMM."
   - On the *new* EP: add `supersedes: [N]`

   **When extending `EP-NNNN`:**
   - On the *old* EP: add M to `extended-by: [...]` (preserve
     existing entries, don't overwrite)
   - On the *new* EP: add `extends: [N]`

### Phase 5 — Validation (hard gate + semantic review)

#### Step 5a: Mechanical validation (hard gate)

Run the validator script on the entire `<ep_dir>`. Directory mode is the
hard gate because it also checks the README catalogue, duplicate numbers,
and every reciprocal file changed in Phase 4. You may validate the new file
alone for fast feedback, but do not treat that as the final pass. If the
`.ep-kit` config has `skip_sections=1`, pass `--skip-sections` to
the validator. If you want structured output (e.g. for CI), pass
`--json`.

If the validator exits non-zero:

1. Read the error output.
2. Fix each reported issue in the EP file.
3. Re-run the validator.
4. Repeat until it exits 0.

Do not hand off an EP that fails mechanical validation. The validator
catches: frontmatter syntax, field presence, enum values, filename
number matching, decision log format, catalogue consistency, strong-link
reciprocity, Implemented release metadata, and cross-reference resolution.

If no validator is available (see Configuration resolution), skip
this step and note it in the handoff.

#### Step 5b: Semantic review

After the validator passes, read through the new EP for the things
the script can't check:

- **Placeholders and TBD.** Replace or delete every one.
- **Internal consistency.** Does the design match the problem?
- **Scope creep.** Is this still one decision space?
- **Ambiguity.** Could any requirement be interpreted two ways? Pick
  one.
- **Decision log honesty.** Does each "Why" answer the question, or
  does it just restate the "Decided"? If the latter, the reasoning
  isn't captured — push the user for it.
- **Frontmatter completeness.** All required fields filled. Numbers
  used in `requires` / `supersedes` / etc. correspond to real EPs.
- **Relationship semantics.** `extends` and `supersedes` need reciprocal
  metadata; `requires` and `see-also` do not. Confirm each field describes
  the real relationship.

Fix inline. No need to ask the user for permission to clean up
mechanical issues — just fix and note them in the handoff.

### Phase 6 — Handoff

Tell the user:

- Path to the new EP.
- Validator outcome (green summary, or "no validator available").
- What other EPs' frontmatter was updated (if any).
- Whether the status is `Placeholder` or `Draft`, what that status permits,
  and what must happen before it can move forward. Neither authorizes
  implementation.
- Whether the README index was updated.
- Any open questions you captured in §"Open questions" that they need
  to decide before acceptance.

Do **not** flip the status to `Accepted` without explicit user
approval. Do **not** commit to git without asking — EP PRs are
typically reviewed before landing.

## Rules

- **One question at a time.** Don't batch questions. The whole point
  of the skill is the guided Q&A.
- **Push back on low-bar EPs.** If the proposal is trivial (a one-off
  refactor, a doc tweak), say so and suggest the user skip the EP
  process. Respect their call if they still want one, but don't rubber
  stamp.
- **Always write a decision log.** Non-negotiable for Standards EPs.
- **Always update the README index** when creating a new EP.
- **Always update linked EPs' reciprocal frontmatter** when extending or
  superseding — same session, not "I'll do it later."
- **Use today's date** for `created:`. Check the current date before
  writing the file (the harness exposes this via the system reminder;
  fall back to `date +%Y-%m-%d` via Bash if uncertain).
- **Default `status: Draft`.** Use `Placeholder` when selected in Q6. Only flip
  either status to `Accepted` through the project's explicit approval process.
- **Use `<prefix>` for the frontmatter number field.** Don't hardcode
  `ep` — the project may use `rfc`, `adr`, `kep`, or another name.

## Red flags to watch for

| Signal                                      | What it means                          |
|---------------------------------------------|----------------------------------------|
| "Just put X in the decision log"            | User is skipping the "why." Push back. |
| "Let's just use the old plan as the EP"     | Retrofit is fine but capture alternatives if they remember any. |
| Answer-in-a-paragraph to scope questions    | Scope is probably too wide. Split.     |
| No non-goals                                | Scope is unbounded. Ask for 2–4.       |
| Single decision log entry on a big proposal | Not dug deep enough. Find more.        |
| "We decided this last week, just write it"  | That's fine — write it, but include the alternatives that lost. |

## Reference

- **Process authority:** `<ep_dir>/0001-ep-purpose-and-guidelines.md`
- **Template:** `<ep_dir>/0000-template.md`
- **Index:** `<ep_dir>/README.md`
- **Validator:** `<validator>` (mechanical checks — hard gate in Phase 5;
  supports `--json` for CI, `--catalogue-json` for validated machine-readable
  proposal metadata, and `--skip-sections` for retrofits)
- **Review skill:** `ep-kit-validate` (semantic review — post-creation audit)
- **Governance skill:** `ep-kit-governance` (preflight routing and post-delivery lifecycle checkpoint)
