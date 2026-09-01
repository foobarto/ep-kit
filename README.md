# Enhancement Proposal Kit (EP Kit)

A reusable framework for capturing, reviewing, and tracking design decisions in software projects. Borrowed from Python's PEP process, Rust's RFCs, and Kubernetes' KEPs — but packaged as a portable skill + template set for AI-assisted development workflows.

## What's in the box

| File | Purpose |
|------|---------|
| `SKILL.md` | AI skill — guided Q&A workflow for creating new EPs |
| `SKILL-VALIDATE.md` | AI skill — semantic review of existing EPs |
| `validate.sh` | Shell script — deterministic mechanical checks (CI-friendly) |
| `install.sh` | One-command installer for scaffolding a project |
| `tests/test.sh` | Regression suite for validator and installer behavior |
| `CHECKLIST.md` | PR review checklist for EP quality gate |
| `CHANGELOG.md` | EP Kit version history |
| `templates/0000-template.md` | Skeleton for new EPs |
| `templates/0001-ep-purpose-and-guidelines.md` | Process document (conventions, lifecycle, rules) |
| `templates/README.md` | Index template for your project's EP directory |
| `examples/0001-example-informational.md` | Example Informational EP (decision record) |
| `examples/0002-example-standards.md` | Example Standards EP (proposed change) |

## Quick start

### 1. Install into your project

```bash
# Scaffolds docs/eps/, vendors scripts/validate-eps.sh, and installs
# discoverable ep-kit + ep-kit-validate skill folders.
./install.sh --skill-dir .claude/skills/

# Custom EP directory
./install.sh docs/rfcs/ --skill-dir .agents/skills/

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

**Validate mechanically:** Run `scripts/validate-eps.sh` for deterministic checks: frontmatter syntax, file naming, catalogue drift, strong reciprocal links, decision log format, section presence, and shipped-release metadata. In the EP Kit checkout itself, run `./validate.sh examples/`.

**Review semantically:** Tell your AI assistant "review EP-3" — the validation skill audits problem clarity, decision log honesty, scope discipline, and internal consistency.

## The two-layer validation model

EP Kit uses a two-layer approach:

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
│  SKILL-VALIDATE.md (semantic/AI)    │
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

## How the creation skill works

The `SKILL.md` runs a **6-phase Q&A workflow**:

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
- **Bootstrap carve-out:** in-place edits are fine before the EP is externally referenced; append-only after

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
