# Strata

A reusable framework for capturing, reviewing, and tracking durable design
decisions in software projects. Borrowed from Python's PEP process, Rust's
RFCs, and Kubernetes' KEPs — but packaged as portable Agent Skills, templates,
and deterministic validation for AI-assisted development workflows.

Strata was named **EP Kit** through version 1.2.0. Existing protocol surfaces
remain stable: `.ep-kit`, `EP-NNNN` citations, and the `ep-kit*` skill and agent
identifiers are retained for installed-project and cross-tool compatibility.

## What's in the box

| File | Purpose |
|------|---------|
| `skills/ep-kit-governance/` | Agent Skill — project-change preflight, EP routing, and completion checkpoint |
| `skills/ep-kit/` | Agent Skill — guided EP authoring plus the deterministic validator helper |
| `skills/ep-kit-validate/` | Agent Skill — semantic review plus the human review checklist |
| `validate.sh` | Repository entry point for the deterministic validator (CI-friendly) |
| `install.sh` | One-command installer for scaffolding a project |
| `tests/test.sh` | Regression suite for validator and installer behavior |
| `agents/ep-kit-reviewer.md` | Optional Claude plugin agent for independent, read-only EP review |
| `.codex-plugin/`, `.claude-plugin/` | Native Codex and Claude plugin metadata |
| `.agents/plugins/marketplace.json` | Codex marketplace catalogue |
| `CHANGELOG.md` | Strata version history |
| `templates/0000-template.md` | Skeleton for new EPs |
| `templates/0001-ep-purpose-and-guidelines.md` | Process document (conventions, lifecycle, rules) |
| `templates/README.md` | Index template for your project's EP directory |
| `examples/0001-example-informational.md` | Example Informational EP (decision record) |
| `examples/0002-example-standards.md` | Example Standards EP (proposed change) |

## Quick start

### 1. Install into your project

```bash
# Scaffolds docs/eps/, vendors scripts/validate-eps.sh, and installs
# discoverable skills under the cross-client .agents/skills/ convention.
./install.sh

# Custom EP directory and harness-specific skills root
./install.sh docs/rfcs/ --skill-dir .agents/skills/

# Governance files only; do not install project-local skills
./install.sh --no-skills

# Dry run to preview
./install.sh --dry-run

# Refresh an existing installation's managed tools without replacing EP docs
./install.sh --upgrade-tools --skill-dir .agents/skills/
```

### 2. Configure (optional)

The installer creates `.ep-kit` with project-relative paths. Edit it if you
need a custom directory, prefix, or validator location:

```
dir=docs/rfcs
prefix=ep
validator=scripts/validate-eps.sh
```

The AI skill reads this to know where to write EPs. The validator accepts the directory as an argument.

### 3. Use it

**Create a new EP:** Tell your AI assistant "new EP for X" — the skill triggers a guided Q&A and produces a well-formed proposal file.

**Run the change preflight:** With the skills installed project-locally,
`ep-kit-governance` is discoverable before project changes. Compatible agents
can use it to classify work as Spike, Bounded, or Architectural, route only
EP-worthy decisions into authoring, apply Draft/Accepted gates, and return
after delivery to assess `Partial` versus `Implemented`. Activation remains
model-driven, so use the behavioral evaluations when changing trigger wording.

**Validate mechanically:** Run `scripts/validate-eps.sh` for deterministic checks: frontmatter syntax, file naming, catalogue drift, strong reciprocal links, decision log format, section presence, and shipped-release metadata. In the Strata checkout itself, run `./validate.sh examples/`.

**Review semantically:** Tell your AI assistant "review EP-0003" — the validation skill audits problem clarity, decision log honesty, scope discipline, and internal consistency.

## The two-layer validation model

Strata uses a two-layer approach:

```
┌─────────────────────────────────────┐
│  validate.sh (deterministic)        │
│  - Frontmatter YAML syntax          │
│  - Filename ↔ ep number match       │
│  - Required fields present          │
│  - Valid enum values (status/type)  │
│  - Cross-file reference existence   │
│  - Strong-link reciprocity          │
│  - README index consistency         │
│  - Implemented release metadata     │
│  - Decision log entry count         │
│  - Section presence by type         │
│  - Unresolved placeholder detection │
│  Exit 0 = pass, 1 = fail            │
└─────────────────┬───────────────────┘
                  │ (only if script passes)
                  ▼
┌─────────────────────────────────────┐
│  ep-kit-validate (semantic/AI)      │
│  - Problem clarity and concreteness │
│  - Goals alignment with problem     │
│  - Non-goals quality                │
│  - Design coherence                 │
│  - Decision log honesty             │
│  - Scope discipline                 │
│  - Migration realism                │
│  - Failure mode coverage            │
│  - Open questions honesty           │
│  Output: structured review report   │
└─────────────────────────────────────┘
```

The script is the gate — if it fails, don't bother the AI. The skill is the review — if the script passes but the EP is hollow, the skill catches it.

## The activation layer

Strata installs a separate governance skill so the authoring skill does not
need to be invoked by name. Its discoverable trigger covers the start, resume,
and completion of project changes in repositories containing `.ep-kit`.

The preflight deliberately exits quickly for work that should not create an EP:

| Class | Meaning | EP action |
|-------|---------|-----------|
| Spike | Exploratory work that reduces uncertainty without setting a durable contract | None; reclassify if it crosses a contract boundary |
| Bounded | Localized, understood change that preserves contracts and invariants | None |
| Architectural | Potentially durable contract, invariant, relationship, or process change | Search existing EPs, then create one only if EP-worthy |

For EP-worthy Architectural work, the EP replaces a parallel design-spec
artifact. Once Accepted, its path becomes the specification passed to whatever
implementation-planning method the project uses. Strata does not prescribe
TDD, worktrees, subagents, debugging, or plan format.

After implementation, the same skill compares delivered evidence with the
Accepted EP and recommends remaining `Accepted`, moving to `Partial`, or moving
to `Implemented`. Lifecycle metadata changes still require explicit authority.

### Lifecycle contract for consumers

| Status | Implementation meaning |
|--------|------------------------|
| Placeholder | Does not authorise implementation |
| Draft | Does not authorise implementation |
| Accepted | Approved implementation may begin under ordinary project authority |
| Partial | Some accepted scope shipped; remaining accepted scope may continue |
| Implemented | All stated accepted goals and rollout obligations shipped |
| Superseded | Follow the replacement proposal |
| Withdrawn / Rejected | Do not implement as an approved design |

A separate, explicit pre-acceptance override may authorise specific scoped
work, including implementation, but the status itself never implies that
override and the proposal remains unaccepted.

## How the creation skill works

The `skills/ep-kit/SKILL.md` skill runs a **6-phase Q&A workflow**:

1. **Scope & framing** — one sentence proposal, trigger, type, related EPs, non-goals, placeholder vs draft
2. **Design** — adaptive depth on shape, interfaces, migration, failure modes, testing
3. **Decision log** — extract every material choice into Decided / Alternatives / Why entries
4. **Write the file** — next number, fill template, update index, update bidirectional links
5. **Self-review** — consistency, scope, decision log honesty, frontmatter completeness
6. **Handoff** — report what was created and what needs review

## Why use this?

- **Chat history rots.** Commit messages are too short. Changelogs record *what*, not *why*.
- **Append-only after acceptance.** Once approved, an EP is a contract — not a wiki page.
- **Decision log is required.** Every non-obvious choice gets documented with alternatives and reasoning.
- **Bidirectional links.** Strong relationships (`extends` / `extended-by`, `supersedes` / `superseded-by`) are mandatory same-PR updates, so navigation never rots.
- **Status lifecycle.** `Placeholder → Draft → Accepted → Partial → Implemented → Superseded` distinguishes incomplete rollout from shipped contracts.
- **Two-layer validation.** Mechanical checks in CI, semantic review by AI — both layers catch different failure modes.

## Conventions at a glance

- **Filename:** `NNNN-short-kebab-title.md` (sequential, 4-digit)
- **Types:** Standards (changes code), Informational (documents decisions), Process (changes workflow)
- **Decision log:** `D1`, `D2`, … numbering — easy to cite from later EPs
- **Stable citations:** `EP-NNNN` for a proposal; `EP-NNNN D<N>` for one of
  its Decision Log entries. These forms do not change with `prefix=`; existing
  unpadded references remain accepted as legacy shorthand.
- **Bootstrap carve-out:** in-place edits are fine before the EP is externally referenced; append-only after

## Supported frontmatter subset

The validator intentionally supports a constrained YAML subset, not arbitrary
YAML. Frontmatter uses top-level `key: scalar` fields, inline or indented scalar
lists for EP relationships, and the documented indented `history` sequence.
Do not use anchors, aliases, tags, flow mappings, block scalars, or custom YAML
types. This keeps validation zero-dependency and makes the accepted syntax a
stable project contract instead of an accidentally growing parser surface.

## Machine-readable catalogue

`validate.sh --catalogue-json <ep-directory>` runs the same deterministic
validation and adds a versioned `proposals` array to the JSON result. Each
entry includes the EP-directory-relative filename in `path`, number, canonical
ID, title, type, status, relationship fields, and `implemented-in`. The
existing `--json` shape remains unchanged.

```bash
scripts/validate-eps.sh --catalogue-json docs/eps/ > ep-catalogue.json
jq '.proposals[] | {id, path, status, extends, "implemented-in": .["implemented-in"]}' ep-catalogue.json
```

Consumers must check the command's exit status before trusting the catalogue;
a non-zero result means the accompanying validation diagnostics found an
invalid proposal set. Catalogue version 1 always emits canonical `EP-NNNN`
IDs even when `.ep-kit` configures another frontmatter number key.

## Behavioral evaluations

`evals/` contains pressure scenarios for the activation boundary: trivial bugs
must avoid EP ceremony, public contracts must route into an EP, Draft EPs must
block implementation, Accepted EPs must replace duplicate design specs, and
completion must distinguish Partial from Implemented. These complement the
deterministic regression suite in `tests/test.sh`.

## Optional companion: Cairn

[Cairn](https://github.com/foobarto/cairn) complements Strata without being a
dependency. Strata manages the life of a durable decision; Cairn manages the
life of implementation work and sessions. When both are present:

- ideas or implementation discoveries may first surface in a Cairn work log;
- architectural decisions are promoted into Strata;
- Accepted or Partial EPs may be decomposed into Cairn execution tasks;
- Cairn may cite `EP-NNNN` and `EP-NNNN D<N>`;
- discoveries that invalidate an accepted decision return to Strata as an
  extending or superseding proposal; and
- Cairn's close or Ship workflow may invoke Strata's completion checkpoint to
  reconcile `Accepted`, `Partial`, and `Implemented` under existing authority.

Strata does not read or write Cairn journals, punch lists, profiles, autonomy
settings, plans, review orchestration, or Ship state. Neither project installs,
imports, or controls the other; the integration is only the textual citation
and lifecycle protocol above.

## Agent Skills and plugin installation

The repository and the installer's output follow the
[Agent Skills specification](https://agentskills.io/specification): each skill
is a directory whose `SKILL.md` has a matching lowercase name and a discovery
description. Installing under `.agents/skills/` uses the documented
cross-client convention and is the generic path for compatible agents.

For native marketplace installation:

```bash
# Codex
codex plugin marketplace add foobarto/strata
codex plugin add strata@strata

# Claude Code
claude plugin marketplace add foobarto/strata
claude plugin install strata@strata
```

Marketplace installs from EP Kit 1.2.0 and earlier use the old
`ep-kit@ep-kit` identity and do not upgrade in place. Reinstall once under the
new identity:

```bash
# Codex
codex plugin remove ep-kit@ep-kit
codex plugin marketplace remove ep-kit
codex plugin marketplace add foobarto/strata
codex plugin add strata@strata

# Claude Code
claude plugin uninstall ep-kit@ep-kit
claude plugin marketplace remove ep-kit
claude plugin marketplace add foobarto/strata
claude plugin install strata@strata
```

Repository-vendored installations need no identity migration; their `.ep-kit`
configuration and `ep-kit*` skill directories remain supported.

Marketplace installation delivers agent behavior; it does not scaffold a
target repository. Initialize that repository with `./install.sh --no-skills`
from a Strata checkout so it receives `.ep-kit`, EP-0001, templates, and the
project validator without duplicating the globally installed skill IDs. Use
plain `./install.sh` instead when repository-vendored, version-pinned skills
are preferred; no marketplace install is needed in that model.

Claude also discovers the optional `ep-kit-reviewer` agent. It provides an
independent, read-only semantic and implementation-status review; it is not an
activation hook and Strata does not require subagents. Codex and other Agent
Skills clients receive the same three core skills without depending on that
Claude-specific agent surface.

For another compatible harness, use `./install.sh --skill-dir <skills-root>`.
The default `.agents/skills/` path is the portable option; a native plugin
manifest is deliberately included only where its current format can be
validated rather than guessed.

## License

Licensed under either of

- Apache License, Version 2.0
  ([LICENSE-APACHE](LICENSE-APACHE) or
  <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license
  ([LICENSE-MIT](LICENSE-MIT) or
  <http://opensource.org/licenses/MIT>)

at your option. Use it in any project.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the Apache-2.0
license, shall be dual licensed as above, without any additional terms
or conditions.
