# Changelog

All notable changes to Strata.

## [1.3.0] — 2026-09-01

### Changed

- Renamed the public project and distribution from EP Kit to **Strata**, with
  the canonical repository moving to `foobarto/strata`.
- Renamed the Codex and Claude marketplace/plugin identity to `strata` and
  updated installation, homepage, repository, and companion-project links.
- Documented the one-time marketplace reinstall required when upgrading an
  existing `ep-kit@ep-kit` installation to `strata@strata`.
- Preserved `.ep-kit`, `EP-NNNN` / `EP-NNNN D<N>`, and the `ep-kit*` skill and
  agent identifiers as stable compatibility and cross-tool protocol surfaces.

## [1.2.0] — 2026-09-01

### Added

- Project-local `ep-kit-governance` skill for change preflight, Spike / Bounded
  / Architectural classification, existing-EP discovery, lifecycle gates, and
  post-implementation status checks.
- Harness-neutral behavioral evaluation scenarios covering over-activation,
  missed architectural activation, Draft/Accepted gates, duplicate design
  artifacts, Partial completion, upward reclassification, and architectural
  decisions discovered during implementation.
- Explicit interoperability contract: an EP-worthy design uses the EP as its
  single durable design artifact and hands an Accepted EP to downstream
  implementation planning as the specification.
- Native Codex and Claude plugin/marketplace manifests, plus an optional
  read-only Claude `ep-kit-reviewer` agent for independent skeptical review.
- Stable cross-tool citations: `EP-NNNN` for proposals and `EP-NNNN D<N>` for
  Decision Log entries, independent of the configurable frontmatter key.
- `--catalogue-json` validator mode, which preserves deterministic diagnostics
  and adds a versioned proposal catalogue with canonical IDs, paths, lifecycle,
  relationships, and release metadata.
- Protocol-only Cairn interoperability documentation covering decision
  promotion, execution handoff, citations, and lifecycle reconciliation.

### Changed

- The installer now vendors all three project-local skills by default under
  `.agents/skills/`, supports an explicit `--no-skills` opt-out, and records
  kit version `1.2.0`.
- Skill sources now use the canonical `skills/<name>/SKILL.md` layout directly;
  the repository validator entry point delegates to the helper packaged with
  the `ep-kit` skill.
- The supported frontmatter language is explicitly frozen to the documented
  constrained YAML subset, and YAML-ambiguous unquoted scalars are rejected;
  EP Kit does not claim general YAML parsing.
- The authoring skill reuses completed brainstorming instead of repeating
  answered questions.
- Lifecycle semantics now form an explicit consumer contract, and guidance
  distinguishes reversible implementation details from architectural choices
  that require an extending or superseding EP.

### Fixed

- Placeholder authoring now preserves the selected status in frontmatter,
  history, and handoff instead of silently hard-coding Draft.
- Runtime validator and installer paths avoid Bash 4 associative arrays, BSD
  `find` incompatibilities, and GNU-only `chmod --reference`, retaining the
  zero-package Linux/macOS path.
- Lifecycle routing now defines explicit Draft overrides consistently and runs
  completion checks for Process as well as Standards EPs.
- Behavioral cases keep their rubrics hidden, treat explicit status-update
  requests as authority, and stage Spike reclassification evidence correctly.
- Marketplace-installed skills resolve their bundled validator relative to the
  loaded skill without persisting an ephemeral plugin-cache path.
- Flow sequences are rejected in scalar-only frontmatter fields and remain
  supported only for documented EP relationship fields.
- The optional Claude reviewer is tool-enforced read-only; deterministic
  validator output must be supplied by its invoking agent.
- Proposal filenames containing line breaks fail cleanly before newline-based
  Bash 3-compatible enumeration, without split paths or leaked tool errors.
- Relationship values cannot expand as shell wildcards against ambient files,
  Decision Log identifiers must be unique citation targets, and explicit
  symlink proposal targets fail closed.

## [1.1.0] — 2026-09-01

### Added

- `Partial` lifecycle status for proposals with shipped slices and open goals.
- Explicit `extends` / `extended-by` reciprocity, separate from `requires`.
- README index validation against proposal number, title, link, type, and status.
- Support for both numeric references and quoted canonical labels such as
  `"EP-0001"`.
- Regression coverage for JSON output, malformed references, reciprocal links,
  catalogue drift, duplicate numbers, and installer layout.

### Changed

- The installer now vendors the validator at a project-relative path instead
  of recording the installer's absolute path.
- `install.sh --upgrade-tools` refreshes managed validators and skills plus the
  two managed config keys without overwriting project EP templates.
- `--skill-dir` now creates discoverable `ep-kit/` and `ep-kit-validate/`
  skill folders.
- Implemented Standards EPs must name their first shipped release with
  `implemented-in`.
- Process EPs may use process-specific structure rather than the Standards and
  Informational section set.
- Decision-log scanning no longer starts three subprocesses per input line,
  keeping large catalogues practical to validate.

### Fixed

- Removed duplicated unreachable shell text that made `bash -n validate.sh`
  fail in the v1.0.0 release.
- `--json` now emits valid JSON for multiple files and global diagnostics.
- `requires` no longer incorrectly implies an `extended-by` backlink.
- The valid `Placeholder` lifecycle name no longer triggers unresolved-marker
  warnings; legacy `requires` / `extended-by` pairs pass with a migration
  warning.
- Removed the unsupported `version` key from skill frontmatter.
- Zero-padded frontmatter numbers now compare correctly with zero-padded
  filenames.
- Malformed proposal numbers now produce validation errors without aborting
  the validation run.
- History entries now require their own valid date and lifecycle status.
- The validator now honors `dir=` relative to a discovered `.ep-kit` file,
  including when invoked from a nested project directory without a target.
- Quoted scalar frontmatter is normalized for index checks, duplicate index
  rows are rejected, and early parse failures count as checked files.
- Filenames now enforce the documented lowercase kebab-case convention.
- Quoted scalar values with inline comments are normalized, supersession
  history must mirror top-level metadata, and JSON diagnostics escape control
  characters.
- Legacy scalar `superseded-by` remains accepted with a migration warning.
- Installer argument parsing now rejects a second positional target even when
  the first is the default path.
- Missing installer option values and validator paths outside the target
  project are rejected before writes begin.
- Migration guidance now installs the complete kit rather than piping the
  standalone installer without its required sibling files.
- Quoted history scalars and escaped quotes in scalar frontmatter are
  normalized consistently; the index template now documents required history.
- Large EP bodies no longer produce false missing-section errors from
  `grep -q`/`pipefail` SIGPIPE interactions.

## [1.0.0] — 2026-04-30

First stable release. The schema, skill workflow, and validator
contract are now considered stable; future breaking changes will be
gated behind a major version bump.

### Added

- **Duplicate-number detection** — `validate.sh` now flags two EPs
  claiming the same number when run in directory mode, before any
  per-file validation runs.
- **JSON output for directory mode** — `validate.sh --json` now emits
  a single well-formed document covering every EP scanned plus a
  summary block (`files_checked`, `errors`, `warnings`).

### Changed

- **Stable file enumeration** — directory mode now collects EP files
  via a sorted `find` that explicitly skips `0000-template.md`,
  removing shell-glob edge cases on case-insensitive filesystems.
- **Template `created:` field** — `templates/0000-template.md` now
  ships with a real ISO date placeholder so a fresh copy passes the
  validator without manual frontmatter surgery.

## [0.2.0] — 2026-04-17

### Added

- **`.github/workflows/validate.yml`** — GitHub Actions CI workflow for EP validation on PRs and pushes
- **`MIGRATION.md`** — Migration guide for ADR, GEP, RFC, and wiki-based decision records
- **`examples/0003-example-custom-prefix.md`** — Example demonstrating custom prefix configuration
- **`--no-autoconfig` flag** — `validate.sh` option to disable `.ep-kit` auto-discovery

### Changed

- CI workflow now falls back to `examples/` directory when `docs/eps/` doesn't exist
- Removed Glorbo/GEP-specific references from `validate.sh`, `SKILL.md`, and `install.sh`

## [0.1.0] — 2026-04-17

Initial release.

### Added

- **SKILL.md** — AI skill for the 6-phase Q&A EP creation workflow
- **templates/0000-template.md** — Skeleton for new EPs with frontmatter, sections, and decision log
- **templates/0001-ep-purpose-and-guidelines.md** — Process document defining the EP lifecycle, conventions, and rules
- **templates/README.md** — Index template for project EP directories
- **install.sh** — One-command installer that scaffolds `docs/eps/` and optionally copies the skill
- **CHECKLIST.md** — PR review checklist for EP quality gate
- **examples/0001-example-informational.md** — Example Informational EP showing "what good looks like"
- **examples/0002-example-standards.md** — Example Standards EP with full decision log
